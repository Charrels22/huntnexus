import { createFileRoute } from "@tanstack/react-router";
import { useEffect } from "react";

export const Route = createFileRoute("/characters")({ component: RedirectToWorkspace });

function RedirectToWorkspace() {
  useEffect(() => {
    if (typeof window !== "undefined") window.location.replace(`/${window.location.search}#personagens`);
  }, []);
  return null;
}
