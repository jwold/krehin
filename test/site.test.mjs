import {describe, expect, it} from "vitest";
import eleventyConfig from "../eleventy.config.js";

describe("site collections", () => {
    it("excludes drafts from published posts and sorts oldest first", () => {
        const posts = [
            {date: new Date("2026-07-11T02:00:00Z"), data: {}},
            {date: new Date("2026-07-11T03:00:00Z"), data: {draft: true}},
            {date: new Date("2026-07-11T01:00:00Z"), data: {}}
        ];

        expect(eleventyConfig.publishedPostsFrom(posts)).toEqual([posts[2], posts[0]]);
    });
});
