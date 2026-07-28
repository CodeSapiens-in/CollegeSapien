type ApiMethod = "GET" | "POST" | "PATCH" | "DELETE" | "PUT";

export const useApi = () => {
  const { $api } = useNuxtApp();

  const request = <T = unknown>(
    method: ApiMethod,
    path: string,
    body?: Record<string, unknown>,
  ) => $api<T>(path, { method, body });

  return {
    get: <T = unknown>(path: string) => request<T>("GET", path),
    post: <T = unknown>(path: string, body?: Record<string, unknown>) =>
      request<T>("POST", path, body),
    patch: <T = unknown>(path: string, body?: Record<string, unknown>) =>
      request<T>("PATCH", path, body),
    delete: <T = unknown>(path: string) => request<T>("DELETE", path),
    put: <T = unknown>(path: string, body?: Record<string, unknown>) =>
      request<T>("PUT", path, body),
  };
};
