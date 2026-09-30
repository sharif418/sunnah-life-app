// ESLint 9 flat config — @sunnahlife/api
// TypeScript project (NestJS + Prisma + jest + bun scripts). Pragmatic rule
// relaxations mirror the web workspace so Bengali-first app code (DTO
// decorators, mapped rows, deliberate non-null assertions after guards) stays
// readable; everything else uses the recommended sets.
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: [
      "dist/**",
      "node_modules/**",
      "coverage/**",
      "storage/**",
      "openapi.json",
      "prisma/migrations/**",
      // Generated Prisma client (bun-workspaces layout generates into the
      // package — see prisma/schema.prisma generator.output)
      "src/generated/**",
    ],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unused-vars": [
        "warn",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/no-non-null-assertion": "off",
      "@typescript-eslint/ban-ts-comment": "off",
      "@typescript-eslint/no-require-imports": "off",
      "no-console": "off",
      "no-empty": "off",
      "prefer-const": "off",
      "no-case-declarations": "off",
    },
  },
  {
    // Plain-Node CJS dev scripts (scripts/dev-run.cjs) — require/__dirname
    // are the point there (the module-cache aliasing needs require.cache).
    files: ["scripts/**/*.cjs"],
    languageOptions: {
      sourceType: "commonjs",
      globals: { require: "readonly", module: "readonly", console: "readonly", __dirname: "readonly" },
    },
    rules: {
      "@typescript-eslint/no-require-imports": "off",
    },
  }
);
