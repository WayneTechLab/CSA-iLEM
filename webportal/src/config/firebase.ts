import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { initializeApp } from "firebase/app";
export const app = initializeApp({
  apiKey: "AIzaSyBJT7oBs9hTxHVcNA81Ct7SFn3a3DgyqmU",
  authDomain: "csa-ilem.firebaseapp.com",
  projectId: "csa-ilem",
  storageBucket: "csa-ilem.firebasestorage.app",
  messagingSenderId: "926115230243",
  appId: "1:926115230243:web:b2d3ffac08baa20a71b796",
});
export const auth = getAuth(app);
export const db = getFirestore(app, "portal");
export const storage = null;
