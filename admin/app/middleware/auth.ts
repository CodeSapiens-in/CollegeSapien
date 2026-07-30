export default defineNuxtRouteMiddleware(async (to) => {
  if (to.path === "/login") return;

  const authStore = useAuthStore();

  // Wait for Firebase onAuthStateChanged to fire before evaluating.
  // isInitialized is set to true after the first auth state callback.
  if (!authStore.isInitialized) {
    await until(() => authStore.isInitialized).toBe(true, { timeout: 5000 });
  }

  if (!authStore.isAuthenticated) {
    return navigateTo("/login");
  }

  if (!authStore.canModerate) {
    return navigateTo("/login");
  }

  if (authStore.user?.role === "ambassador") {
    const allowed = ["/resources", "/moderation", "/events"];
    const isAllowed = allowed.some(
      (p) => to.path === p || to.path.startsWith(p + "/"),
    );
    if (!isAllowed) {
      return navigateTo("/resources");
    }
  }
});
