export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig();
  const router = useRouter();

  const api = $fetch.create({
    baseURL: config.public.apiBaseUrl,
    async onRequest({ options }) {
      const headers = new Headers(options.headers);
      if (!headers.has("Authorization")) {
        const { getToken } = useFirebaseAuth();
        const token = await getToken();
        if (token) headers.set("Authorization", `Bearer ${token}`);
      }
      options.headers = headers;
    },
    onResponseError({ response }) {
      if (response.status === 401) {
        router.push("/login");
      }
    },
  });

  return {
    provide: { api },
  };
});
