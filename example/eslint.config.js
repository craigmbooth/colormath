// Thin caller of the vendored colormath eslint base. Customize via factory
// options or by appending flat-config blocks (later entries win).
import { colormathConfig } from "./eslint.config.colormath.mjs";

export default [...colormathConfig()];
