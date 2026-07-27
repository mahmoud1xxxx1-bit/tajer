import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyCYLpEIYZU1uuKZXxKBz7sa0Xk-cicnQ7Y",
  appId: "1:88663100884:web:0913563caf37cfd6a09a41",
  messagingSenderId: "88663100884",
  projectId: "tajer-19289",
  authDomain: "tajer-19289.firebaseapp.com",
  storageBucket: "tajer-19289.firebasestorage.app",
  measurementId: "G-N08GHPYTXV"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
