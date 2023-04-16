module.exports = function(eleventyConfig) {
    eleventyConfig.addPassthroughCopy("style.css");
    eleventyConfig.addPassthroughCopy("style.css.map");
    eleventyConfig.addPassthroughCopy("godot_game");
    eleventyConfig.addPassthroughCopy("coi-serviceworker.js");
    return {
        dir: {
            output: "docs"
        }
    }
};