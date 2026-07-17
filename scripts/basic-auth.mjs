function parseBasicAuth(header = "") {
  if (!header.startsWith("Basic ")) return null;
  const decoded = Buffer.from(header.slice(6), "base64").toString("utf8");
  const separator = decoded.indexOf(":");
  if (separator < 0) return null;
  return {
    username: decoded.slice(0, separator),
    password: decoded.slice(separator + 1),
  };
}

export function basicAuthApi(options = {}) {
  const setting = (name, fallback = "") => options.env?.[name] || process.env[name] || fallback;

  const handler = (req, res, next) => {
    const expectedUser = setting("WARDROBE_AUTH_USER", "wardrobe");
    const expectedPassword = setting("WARDROBE_AUTH_PASSWORD");
    if (!expectedPassword) return next();

    const url = new URL(req.url, "http://localhost");
    if (url.pathname === "/api/import/config") return next();

    const credentials = parseBasicAuth(req.headers.authorization);
    if (credentials?.username === expectedUser && credentials.password === expectedPassword) {
      return next();
    }

    res.statusCode = 401;
    res.setHeader("WWW-Authenticate", 'Basic realm="Wardrobe", charset="UTF-8"');
    res.end("Authentication required");
  };

  return {
    name: "wardrobe-basic-auth",
    apply: "serve",
    configureServer(server) {
      server.middlewares.use(handler);
    },
    configurePreviewServer(server) {
      server.middlewares.use(handler);
    },
  };
}
