import {createContext,useContext} from "react";
import type {User} from "firebase/auth";
export const Session = createContext<{
  user: User | null;
  level: number;
  loading: boolean;
}>({ user: null, level: 0, loading: true });
export const useSession = () => useContext(Session);
