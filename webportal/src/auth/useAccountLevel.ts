import { useSession } from "@/portal/useSession";
import {
  getAccountCapabilities,
  getAccountLevelDefinition,
} from "./accountLevels";
export function useAccountLevel() {
  const { level } = useSession();
  return {
    level,
    definition: getAccountLevelDefinition(level),
    capabilities: getAccountCapabilities(level),
  };
}
