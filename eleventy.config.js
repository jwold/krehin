const {EleventyHtmlBasePlugin} = require("@11ty/eleventy");
const pluginRss = require("@11ty/eleventy-plugin-rss").default;

const TIME_ZONE = "America/Los_Angeles";

function localDay(date) {
    const parts = new Intl.DateTimeFormat("en-US", {
        timeZone: TIME_ZONE,
        year: "numeric",
        month: "2-digit",
        day: "2-digit"
    }).formatToParts(new Date(date));
    const values = Object.fromEntries(parts.map(({type, value}) => [type, value]));
    return `${values.year}-${values.month}-${values.day}`;
}

module.exports = function (eleventyConfig) {
    eleventyConfig.addPlugin(EleventyHtmlBasePlugin);
    eleventyConfig.addPlugin(pluginRss);
    eleventyConfig.addPassthroughCopy({"src/assets": "assets"});
    eleventyConfig.addPassthroughCopy("src/appcast.xml");

    eleventyConfig.addFilter("readableDate", (date) => new Intl.DateTimeFormat("en-US", {
        timeZone: TIME_ZONE,
        month: "short",
        day: "numeric",
        year: "numeric"
    }).format(new Date(date)));

    eleventyConfig.addFilter("isoDate", (date) => new Date(date).toISOString());
    eleventyConfig.addFilter("absoluteSiteUrl", (path, base) => {
        return `${String(base).replace(/\/$/, "")}/${String(path).replace(/^\//, "")}`;
    });
    eleventyConfig.addFilter("latestDate", (posts) => {
        if (!posts.length) return new Date("2026-07-10T00:00:00Z").toISOString();
        return new Date(Math.max(...posts.map((post) => post.date))).toISOString();
    });
    eleventyConfig.addFilter("json", (value) => JSON.stringify(value));

    eleventyConfig.addCollection("postDays", (collectionApi) => {
        const posts = collectionApi.getFilteredByTag("posts")
            .filter((post) => !post.data.draft)
            .sort((a, b) => new Date(b.date) - new Date(a.date));
        const groups = [];

        for (const post of posts) {
            const day = localDay(post.date);
            const current = groups.at(-1);
            if (!current || current.day !== day) {
                groups.push({day, posts: [post]});
            } else {
                current.posts.push(post);
            }
        }

        return groups;
    });

    return {
        pathPrefix: process.env.PATH_PREFIX || "/",
        dir: {
            input: "src",
            output: "_site",
            includes: "_includes",
            data: "_data"
        },
        markdownTemplateEngine: "njk",
        htmlTemplateEngine: "njk"
    };
};
