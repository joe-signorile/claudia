import { renderProfile } from "./profile";
import { logAccess } from "./audit";

const usr = { id: "1", name: "Ada" };
renderProfile(usr);
logAccess(usr, "login");
