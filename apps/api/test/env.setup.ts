// Jest environment bootstrap (Phase C/W2c): loads apps/api/.env with
// override semantics for the DATABASE/REDIS variables.
//
// Why an explicit setup (and not dotenv's default): the sandbox/dev shell
// exports DATABASE_URL=file:… for the WEB app — an artifact, not an API
// deployment decision. In production/Docker there is no .env at all and the
// real environment wins (app.module loads dotenv WITHOUT override there).
// Tests deliberately pin the API's own .env so the suite is hermetic.
import { config as loadDotenv } from "dotenv";
import { join } from "path";

loadDotenv({ path: join(__dirname, "..", ".env"), override: true, quiet: true });
