import {describe, expect, it, vi} from "vitest";
import {handleRequest, testing} from "../src/index";

const env = {
    GITHUB_OWNER: "jwold",
    GITHUB_REPO: "krehin",
    GITHUB_BRANCH: "main",
    POSTS_DIRECTORY: "src/posts",
    SITE_URL: "https://jwold.github.io/krehin",
    GITHUB_TOKEN: "github-secret",
    MICROPUB_TOKEN: "micropub-secret"
} as Env;

describe("Krehin publisher", () => {
    it("rejects requests without the publishing token", async () => {
        const request = new Request("https://publisher.example/micropub", {method: "POST"});
        const response = await handleRequest(request, env);
        expect(response.status).toBe(401);
    });

    it("commits a form post as Markdown and returns its permalink", async () => {
        const fetcher = vi.fn<typeof fetch>(async () => Response.json({content: {sha: "abc"}}, {status: 201}));
        const request = new Request("https://publisher.example/micropub", {
            method: "POST",
            headers: {
                authorization: "Bearer micropub-secret",
                "content-type": "application/x-www-form-urlencoded"
            },
            body: new URLSearchParams({
                name: "A useful thought",
                content: "> A quoted line\n\nAnd a response.",
                published: "2026-07-10T09:00:00-07:00"
            })
        });

        const response = await handleRequest(request, env, fetcher as typeof fetch);
        expect(response.status).toBe(201);
        expect(response.headers.get("location")).toMatch(/^https:\/\/jwold\.github\.io\/krehin\/2026-07-10-a-useful-thought-[a-f0-9]{8}\/$/);

        const [url, init] = fetcher.mock.calls[0];
        expect(url).toContain("/repos/jwold/krehin/contents/src/posts/2026-07-10-a-useful-thought-");
        const payload = JSON.parse(String(init?.body));
        const markdown = Buffer.from(payload.content, "base64").toString("utf8");
        expect(markdown).toContain("date: 2026-07-10T16:00:00.000Z");
        expect(markdown).not.toContain('date: "2026-07-10T16:00:00.000Z"');
        expect(markdown).toContain('title: "A useful thought"');
        expect(markdown).toContain("> A quoted line\n\nAnd a response.");
    });

    it("parses Micropub JSON content and categories", () => {
        const post = testing.fromJson(JSON.stringify({
            type: ["h-entry"],
            properties: {content: ["Hello"], category: ["notes", "web"]}
        }));
        expect(post.content).toBe("Hello");
        expect(post.categories).toEqual(["notes", "web"]);
    });

    it("updates the Markdown behind an existing permalink", async () => {
        const existing = [
            "---",
            "date: 2026-07-10T16:00:00.000Z",
            'slug: "existing-note"',
            'categories: ["notes"]',
            "---",
            "",
            "Old body",
            ""
        ].join("\n");
        const fetcher = vi.fn<typeof fetch>()
            .mockResolvedValueOnce(Response.json({
                sha: "existing-sha",
                encoding: "base64",
                content: Buffer.from(existing).toString("base64")
            }))
            .mockResolvedValueOnce(Response.json({content: {sha: "updated-sha"}}, {status: 200}));
        const request = new Request("https://publisher.example/micropub", {
            method: "POST",
            headers: {
                authorization: "Bearer micropub-secret",
                "content-type": "application/x-www-form-urlencoded"
            },
            body: new URLSearchParams({
                action: "update",
                url: "https://jwold.github.io/krehin/existing-note/",
                "replace[name]": "Updated title",
                "replace[content]": "Updated body"
            })
        });

        const response = await handleRequest(request, env, fetcher);
        expect(response.status).toBe(204);
        expect(fetcher).toHaveBeenCalledTimes(2);
        const updatePayload = JSON.parse(String(fetcher.mock.calls[1][1]?.body));
        const markdown = Buffer.from(updatePayload.content, "base64").toString("utf8");
        expect(updatePayload.sha).toBe("existing-sha");
        expect(markdown).toContain("date: 2026-07-10T16:00:00.000Z");
        expect(markdown).toContain('categories: ["notes"]');
        expect(markdown).toContain('title: "Updated title"');
        expect(markdown).toContain("Updated body");
    });

    it("deletes the Markdown behind an existing permalink", async () => {
        const fetcher = vi.fn<typeof fetch>()
            .mockResolvedValueOnce(Response.json({sha: "existing-sha", encoding: "base64", content: "YQ=="}))
            .mockResolvedValueOnce(new Response(null, {status: 200}));
        const request = new Request("https://publisher.example/micropub", {
            method: "POST",
            headers: {
                authorization: "Bearer micropub-secret",
                "content-type": "application/x-www-form-urlencoded"
            },
            body: new URLSearchParams({
                action: "delete",
                url: "https://jwold.github.io/krehin/existing-note/"
            })
        });

        const response = await handleRequest(request, env, fetcher);
        expect(response.status).toBe(204);
        expect(fetcher.mock.calls[1][1]?.method).toBe("DELETE");
        expect(JSON.parse(String(fetcher.mock.calls[1][1]?.body)).sha).toBe("existing-sha");
    });

    it("rejects mutations outside the Krehin site", () => {
        expect(() => testing.slugFromPermalink("https://example.com/post/", env)).toThrow("Only Krehin");
    });

    it("rejects oversized posts before committing", async () => {
        const request = new Request("https://publisher.example/micropub", {
            method: "POST",
            headers: {
                authorization: "Bearer micropub-secret",
                "content-type": "application/x-www-form-urlencoded",
                "content-length": String(129 * 1024)
            },
            body: "content=hello"
        });
        const response = await handleRequest(request, env, vi.fn() as typeof fetch);
        expect(response.status).toBe(413);
    });
});
