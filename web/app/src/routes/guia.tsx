import { createFileRoute } from "@tanstack/react-router";
import { useEffect } from "react";

export const Route = createFileRoute("/guia")({ component: RedirectToWorkspace });

function RedirectToWorkspace() {
  useEffect(() => {
    if (typeof window !== "undefined") window.location.replace(`/${window.location.search}${window.location.hash}`);
  }, []);
  return null;
}
