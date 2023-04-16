module.exports = function(eleventyConfig) {
    eleventyConfig.addPassthroughCopy("style.css");
    eleventyConfig.addPassthroughCopy("style.css.map");
    eleventyConfig.addPassthroughCopy("godot_game");
}