import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    files: ["static/js/**/*.js"],
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: "module",
    },
  },
];
