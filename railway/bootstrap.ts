// Railway first-boot bootstrap for Wishlist.
// Upstream makes the first person who signs up the admin. On a public URL that
// would let any visitor claim the instance, so on the first boot this creates
// the admin from generated variables and switches public sign-up off, before
// the public port opens. On later boots it does nothing.
import { scryptSync, randomBytes } from "node:crypto";
import { init } from "@paralleldrive/cuid2";
import { prisma } from "./client";

const ADMIN_ROLE = 2;

function hashPassword(password: string): string {
    // Same format as src/lib/server/password.ts: s2:<hex salt>:<hex scrypt key>
    const salt = randomBytes(16).toString("hex");
    const key = scryptSync(password.normalize("NFKC"), salt, 64, {
        N: 16384,
        r: 16,
        p: 1,
        maxmem: 64 * 1024 * 1024
    });
    return `s2:${salt}:${key.toString("hex")}`;
}

async function main() {
    const users = await prisma.user.count();
    if (users > 0) {
        console.log("[railway] admin bootstrap: %d user(s) already exist, nothing to do", users);
        return;
    }

    const username = (process.env.WISHLIST_ADMIN_USERNAME || "admin").trim();
    const name = (process.env.WISHLIST_ADMIN_NAME || "Admin").trim();
    const email = (process.env.WISHLIST_ADMIN_EMAIL || "admin@example.com").trim();
    const password = process.env.WISHLIST_ADMIN_PASSWORD || "";

    if (password.length < 12) {
        throw new Error("WISHLIST_ADMIN_PASSWORD is missing or shorter than 12 characters; refusing to start with open sign-up");
    }
    if (!username) throw new Error("WISHLIST_ADMIN_USERNAME is empty");

    const group = await prisma.group.findFirst({ select: { id: true } });
    if (!group) throw new Error("no group found after seeding");

    const listId = init({ length: 10 })();
    await prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
            select: { id: true },
            data: { username, name, email, roleId: ADMIN_ROLE, hashedPassword: hashPassword(password) }
        });
        await tx.userGroupMembership.create({ data: { userId: user.id, groupId: group.id, active: true } });
        await tx.list.create({ data: { id: listId, ownerId: user.id, groupId: group.id } });
        // Invite-only from now on. The admin can turn public sign-up back on in Admin > Settings.
        await tx.systemConfig.upsert({
            where: { key_groupId: { key: "enableSignup", groupId: "global" } },
            create: { key: "enableSignup", groupId: "global", value: "false" },
            update: { value: "false" }
        });
    });
    console.log("[railway] admin bootstrap: created admin '%s' and switched public sign-up off", username);
}

main()
    .then(() => prisma.$disconnect())
    .catch(async (e) => {
        console.error("[railway] admin bootstrap FAILED:", e instanceof Error ? e.message : e);
        await prisma.$disconnect();
        process.exit(1);
    });
