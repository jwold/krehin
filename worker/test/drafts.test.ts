import {describe, expect, it} from "vitest";
import {handleRequest} from "../src/index";

function memoryKV(seed: Record<string, unknown> = {}) {
    const store = new Map<string, string>(Object.entries(seed).map(([key, value]) => [key, JSON.stringify(value)]));
    return {
        store,
        async get(key: string) {
            const value = store.get(key);
            return value === undefined ? null : JSON.parse(value);
        },
        async put(key: string, value: string) {
            store.set(key, value);
        },
        async delete(key: string) {
            store.delete(key);
        },
        async list({prefix = ""}: {prefix?: string; cursor?: string} = {}) {
            return {
                keys: Array.from(store.keys()).filter((key) => key.startsWith(prefix)).map((name) => ({name})),
                list_complete: true as const,
                cacheStatus: null
            };
        }
    };
}

function draft(overrides: Record<string, unknown> = {}) {
    return {
        id: "11111111-2222-3333-4444-555555555555",
        title: "",
        body: "A draft from the phone",
        status: "draft",
        createdAt: "2026-08-21T10:00:00.000Z",
        modifiedAt: "2026-08-21T10:00:00.000Z",
        publishedAt: null,
        remoteUrl: "",
        lastPublishedTitle: "",
        lastPublishedBody: "",
        deletedAt: null,
        ...overrides
    };
}

function envWith(kv: ReturnType<typeof memoryKV>) {
    return {
        GITHUB_OWNER: "jwold",
        GITHUB_REPO: "krehin",
        GITHUB_BRANCH: "main",
        POSTS_DIRECTORY: "src/posts",
        SITE_URL: "https://krehin.com",
        GITHUB_TOKEN: "github-secret",
        MICROPUB_TOKEN: "micropub-secret",
        DRAFTS: kv
    } as unknown as Env;
}

function syncRequest(records: unknown[]) {
    return new Request("https://publisher.example/drafts", {
        method: "POST",
        headers: {authorization: "Bearer micropub-secret", "content-type": "application/json"},
        body: JSON.stringify({records})
    });
}

describe("draft sync", () => {
    it("reads every draft from a single key instead of one read per draft", async () => {
        const kv = memoryKV({
            "drafts:v1": {
                "11111111-2222-3333-4444-555555555555": draft(),
                "22222222-3333-4444-5555-666666666666": draft({id: "22222222-3333-4444-5555-666666666666", body: "Second"})
            }
        });
        const reads: string[] = [];
        const counted = {...kv, get: async (key: string) => { reads.push(key); return kv.get(key); }};

        const response = await handleRequest(syncRequest([]), envWith(counted as ReturnType<typeof memoryKV>));

        const payload = await response.json() as {records: unknown[]};
        expect(payload.records).toHaveLength(2);
        expect(reads).toEqual(["drafts:v1"]);
    });

    it("folds drafts stored under the old per-draft keys into the combined value", async () => {
        const kv = memoryKV({"draft:11111111-2222-3333-4444-555555555555": draft({body: "Written before the migration"})});

        const response = await handleRequest(syncRequest([]), envWith(kv));

        const payload = await response.json() as {records: {body: string}[]};
        expect(payload.records[0].body).toBe("Written before the migration");
        expect(kv.store.has("draft:11111111-2222-3333-4444-555555555555")).toBe(false);
        expect(Object.keys(JSON.parse(kv.store.get("drafts:v1") || "{}"))).toHaveLength(1);
    });

    it("rejects unauthorized sync requests", async () => {
        const response = await handleRequest(new Request("https://publisher.example/drafts", {method: "POST"}), envWith(memoryKV()));
        expect(response.status).toBe(401);
    });

    it("stores an incoming draft and echoes the merged set", async () => {
        const kv = memoryKV();
        const response = await handleRequest(syncRequest([draft()]), envWith(kv));
        expect(response.status).toBe(200);
        const payload = await response.json() as {records: {id: string; body: string}[]};
        expect(payload.records).toHaveLength(1);
        expect(payload.records[0].body).toBe("A draft from the phone");
        expect(Object.keys(JSON.parse(kv.store.get("drafts:v1") || "{}"))).toHaveLength(1);
    });

    it("keeps the newer edit when both sides changed", async () => {
        const kv = memoryKV({
            "draft:11111111-2222-3333-4444-555555555555": draft({body: "Newer on the server", modifiedAt: "2026-08-21T12:00:00.000Z"})
        });
        const response = await handleRequest(syncRequest([draft({body: "Older from the client"})]), envWith(kv));
        const payload = await response.json() as {records: {body: string}[]};
        expect(payload.records[0].body).toBe("Newer on the server");
    });

    it("accepts a client edit that is newer than the stored copy", async () => {
        const kv = memoryKV({
            "draft:11111111-2222-3333-4444-555555555555": draft({body: "Older on the server"})
        });
        const response = await handleRequest(
            syncRequest([draft({body: "Newer from the client", modifiedAt: "2026-08-21T14:00:00.000Z"})]),
            envWith(kv)
        );
        const payload = await response.json() as {records: {body: string}[]};
        expect(payload.records[0].body).toBe("Newer from the client");
    });

    it("returns tombstones so other devices delete the post too", async () => {
        const kv = memoryKV();
        await handleRequest(syncRequest([draft()]), envWith(kv));
        const response = await handleRequest(
            syncRequest([draft({deletedAt: "2026-08-21T15:00:00.000Z", modifiedAt: "2026-08-21T15:00:00.000Z"})]),
            envWith(kv)
        );
        const payload = await response.json() as {records: {deletedAt: string | null}[]};
        expect(payload.records[0].deletedAt).toBe("2026-08-21T15:00:00.000Z");
    });

    it("drops tombstones once they are older than the retention window", async () => {
        const stale = new Date(Date.now() - 120 * 24 * 60 * 60 * 1000).toISOString();
        const kv = memoryKV({
            "draft:11111111-2222-3333-4444-555555555555": draft({deletedAt: stale, modifiedAt: stale})
        });
        const response = await handleRequest(syncRequest([]), envWith(kv));
        const payload = await response.json() as {records: unknown[]};
        expect(payload.records).toHaveLength(0);
        expect(kv.store.has("draft:11111111-2222-3333-4444-555555555555")).toBe(false);
        expect(JSON.parse(kv.store.get("drafts:v1") || "{}")).toEqual({});
    });

    it("rejects identifiers that would escape the draft key space", async () => {
        const response = await handleRequest(syncRequest([draft({id: "../secret"})]), envWith(memoryKV()));
        expect(response.status).toBe(400);
    });
});
