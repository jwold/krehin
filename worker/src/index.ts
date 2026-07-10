import {createHash, timingSafeEqual} from "node:crypto";

const MAX_BODY_BYTES = 128 * 1024;
const GITHUB_API_VERSION = "2026-03-10";

type Fetcher = typeof fetch;

interface PostInput {
    title: string;
    content: string;
    categories: string[];
    published: string;
    requestedSlug: string;
    externalUrl: string;
}

interface MicropubJson {
    type?: unknown;
    properties?: Record<string, unknown>;
}

class RequestError extends Error {
    constructor(public status: number, public code: string, message: string) {
        super(message);
    }
}

function json(data: unknown, status = 200, headers: HeadersInit = {}): Response {
    return Response.json(data, {
        status,
        headers: {"cache-control": "no-store", ...headers}
    });
}

function errorResponse(error: RequestError): Response {
    return json({error: error.code, error_description: error.message}, error.status);
}

function isAuthorized(request: Request, expectedToken: string): boolean {
    const header = request.headers.get("authorization") || "";
    const provided = header.startsWith("Bearer ") ? header.slice(7) : "";
    const expectedHash = createHash("sha256").update(expectedToken).digest();
    const providedHash = createHash("sha256").update(provided).digest();
    return timingSafeEqual(expectedHash, providedHash);
}

async function readLimitedBody(request: Request): Promise<string> {
    const declaredLength = Number(request.headers.get("content-length") || 0);
    if (declaredLength > MAX_BODY_BYTES) {
        throw new RequestError(413, "request_too_large", "Posts must be smaller than 128 KB.");
    }
    if (!request.body) return "";

    const reader = request.body.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;

    while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > MAX_BODY_BYTES) {
            await reader.cancel();
            throw new RequestError(413, "request_too_large", "Posts must be smaller than 128 KB.");
        }
        chunks.push(value);
    }

    const body = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
        body.set(chunk, offset);
        offset += chunk.byteLength;
    }
    return new TextDecoder().decode(body);
}

function firstString(value: unknown): string {
    const item = Array.isArray(value) ? value[0] : value;
    if (typeof item === "string") return item.trim();
    if (item && typeof item === "object") {
        const content = item as Record<string, unknown>;
        if (typeof content.markdown === "string") return content.markdown.trim();
        if (typeof content.html === "string") return content.html.trim();
        if (typeof content.value === "string") return content.value.trim();
    }
    return "";
}

function stringList(value: unknown): string[] {
    const values = Array.isArray(value) ? value : value === undefined ? [] : [value];
    return values.filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter(Boolean);
}

function normalizePublished(value: string): string {
    if (!value) return new Date().toISOString();
    const parsed = new Date(value);
    if (Number.isNaN(parsed.valueOf())) {
        throw new RequestError(400, "invalid_request", "The published date is not valid.");
    }
    return parsed.toISOString();
}

function normalizeExternalUrl(value: string): string {
    if (!value) return "";
    try {
        const url = new URL(value);
        if (url.protocol !== "http:" && url.protocol !== "https:") throw new Error();
        return url.toString();
    } catch {
        throw new RequestError(400, "invalid_request", "The external link must be an HTTP or HTTPS URL.");
    }
}

function fromForm(body: string): PostInput {
    const form = new URLSearchParams(body);
    const content = (form.get("content") || form.get("content[markdown]") || form.get("content[html]") || "").trim();
    const title = (form.get("name") || "").trim();
    return {
        title,
        content,
        categories: form.getAll("category").map((value) => value.trim()).filter(Boolean),
        published: normalizePublished(form.get("published") || ""),
        requestedSlug: (form.get("mp-slug") || "").trim(),
        externalUrl: normalizeExternalUrl(form.get("bookmark-of") || form.get("external-url") || "")
    };
}

function fromJson(body: string): PostInput {
    let parsed: MicropubJson;
    try {
        parsed = JSON.parse(body) as MicropubJson;
    } catch {
        throw new RequestError(400, "invalid_request", "The JSON body could not be parsed.");
    }
    const properties = parsed.properties || {};
    return {
        title: firstString(properties.name),
        content: firstString(properties.content),
        categories: stringList(properties.category),
        published: normalizePublished(firstString(properties.published)),
        requestedSlug: firstString(properties["mp-slug"]),
        externalUrl: normalizeExternalUrl(firstString(properties["bookmark-of"]) || firstString(properties["external-url"]))
    };
}

async function parsePost(request: Request): Promise<PostInput> {
    const contentType = (request.headers.get("content-type") || "").split(";", 1)[0].toLowerCase();
    const body = await readLimitedBody(request);
    let post: PostInput;

    if (contentType === "application/json") {
        post = fromJson(body);
    } else if (contentType === "application/x-www-form-urlencoded") {
        post = fromForm(body);
    } else {
        throw new RequestError(415, "invalid_request", "Use JSON or URL-encoded form data.");
    }

    if (!post.title && !post.content) {
        throw new RequestError(400, "invalid_request", "A title or content is required.");
    }
    return post;
}

function slugify(value: string): string {
    return value.toLowerCase()
        .normalize("NFKD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/<[^>]*>/g, " ")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 64)
        .replace(/-$/g, "") || "note";
}

function randomSuffix(): string {
    const bytes = crypto.getRandomValues(new Uint8Array(4));
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function postSlug(post: PostInput): string {
    const date = post.published.slice(0, 10);
    const source = post.requestedSlug || post.title || post.content.slice(0, 100);
    return `${date}-${slugify(source)}-${randomSuffix()}`;
}

function markdownFor(post: PostInput, slug: string): string {
    const frontmatter = [
        "---",
        `date: ${JSON.stringify(post.published)}`,
        `slug: ${JSON.stringify(slug)}`,
        ...(post.title ? [`title: ${JSON.stringify(post.title)}`] : []),
        ...(post.categories.length ? [`categories: ${JSON.stringify(post.categories)}`] : []),
        ...(post.externalUrl ? [`external_url: ${JSON.stringify(post.externalUrl)}`] : []),
        "---"
    ];
    return `${frontmatter.join("\n")}\n${post.content ? `\n${post.content}\n` : ""}`;
}

async function commitPost(post: PostInput, slug: string, env: Env, fetcher: Fetcher): Promise<void> {
    const path = `${env.POSTS_DIRECTORY}/${slug}.md`;
    const endpoint = `https://api.github.com/repos/${encodeURIComponent(env.GITHUB_OWNER)}/${encodeURIComponent(env.GITHUB_REPO)}/contents/${path.split("/").map(encodeURIComponent).join("/")}`;
    const response = await fetcher(endpoint, {
        method: "PUT",
        headers: {
            accept: "application/vnd.github+json",
            authorization: `Bearer ${env.GITHUB_TOKEN}`,
            "content-type": "application/json",
            "user-agent": "krehin-publisher",
            "x-github-api-version": GITHUB_API_VERSION
        },
        body: JSON.stringify({
            message: `Publish ${slug}`,
            branch: env.GITHUB_BRANCH,
            content: Buffer.from(markdownFor(post, slug), "utf8").toString("base64")
        })
    });

    if (!response.ok) {
        const detail = (await response.text()).slice(0, 500);
        console.error(JSON.stringify({event: "github_commit_failed", status: response.status, detail}));
        throw new RequestError(502, "temporarily_unavailable", "GitHub did not accept the post.");
    }
}

export async function handleRequest(request: Request, env: Env, fetcher: Fetcher = fetch): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/" && request.method === "GET") {
        return json({name: "Krehin publisher", status: "ok"});
    }
    if (url.pathname !== "/micropub") {
        return json({error: "not_found"}, 404);
    }
    if (request.method === "OPTIONS") {
        return new Response(null, {status: 204, headers: {allow: "GET, POST, OPTIONS"}});
    }
    if (!isAuthorized(request, env.MICROPUB_TOKEN)) {
        return json({error: "unauthorized"}, 401, {"www-authenticate": "Bearer"});
    }
    if (request.method === "GET" && url.searchParams.get("q") === "config") {
        return json({"post-types": [{type: "note", name: "Note"}, {type: "article", name: "Article"}]});
    }
    if (request.method !== "POST") {
        return json({error: "invalid_request", error_description: "Use POST to create a post."}, 405, {allow: "GET, POST, OPTIONS"});
    }

    try {
        const post = await parsePost(request);
        const slug = postSlug(post);
        await commitPost(post, slug, env, fetcher);
        const location = `${env.SITE_URL.replace(/\/$/, "")}/${slug}/`;
        console.log(JSON.stringify({event: "post_published", slug}));
        return new Response(null, {status: 201, headers: {location, "cache-control": "no-store"}});
    } catch (error) {
        if (error instanceof RequestError) return errorResponse(error);
        console.error(JSON.stringify({event: "publish_failed", error: error instanceof Error ? error.message : "Unknown error"}));
        return json({error: "server_error", error_description: "The post could not be published."}, 500);
    }
}

export default {
    fetch(request: Request, env: Env): Promise<Response> {
        return handleRequest(request, env);
    }
} satisfies ExportedHandler<Env>;

export const testing = {fromForm, fromJson, markdownFor, slugify};
