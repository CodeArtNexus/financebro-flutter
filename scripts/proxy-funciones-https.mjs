import https from "node:https";
import http from "node:http";
import { readFileSync } from "node:fs";
import { isIP } from "node:net";
const host = process.env.FINANCEBRO_TLS_HOST ?? "127.0.0.1";
const p = host.split(".").map(Number);
const privado =
  isIP(host) === 4 &&
  (p[0] === 127 ||
    p[0] === 10 ||
    (p[0] === 192 && p[1] === 168) ||
    (p[0] === 172 && p[1] >= 16 && p[1] <= 31));
if (!privado)
  throw Error("El puente TLS solo escucha en una dirección privada.");
const puerto = Number(process.env.FINANCEBRO_TLS_PORT ?? 5443),
  destino = Number(process.env.FINANCEBRO_FUNCTIONS_PORT ?? 5001);
if (![puerto, destino].every((n) => Number.isInteger(n) && n > 0 && n < 65536))
  throw Error("Puerto inválido.");
const ruta = "/demo-financebro/us-central1/banca";
const servidor = https.createServer(
  {
    cert: readFileSync(process.env.FINANCEBRO_TLS_CERT),
    key: readFileSync(process.env.FINANCEBRO_TLS_KEY),
    minVersion: "TLSv1.2",
  },
  (req, res) => {
    if (req.method !== "POST" || req.url !== ruta) {
      res.writeHead(404);
      res.end();
      return;
    }
    const partes = [];
    let longitud = 0;
    req.on("data", (p) => {
      longitud += p.length;
      if (longitud > 1048576) {
        req.destroy();
        return;
      }
      partes.push(p);
    });
    req.on("end", () => {
      const cuerpo = Buffer.concat(partes);
      const siguiente = http.request(
        {
          host: "127.0.0.1",
          port: destino,
          path: ruta,
          method: "POST",
          headers: {
            "content-type": "application/json",
            "content-length": cuerpo.length,
            ...(req.headers.authorization
              ? { authorization: req.headers.authorization }
              : {}),
          },
        },
        (r) => {
          res.writeHead(r.statusCode ?? 502, {
            "content-type": r.headers["content-type"] ?? "application/json",
          });
          r.pipe(res);
        },
      );
      siguiente.setTimeout(30000, () => siguiente.destroy());
      siguiente.on("error", () => {
        if (!res.headersSent)
          res.writeHead(503, { "content-type": "application/json" });
        res.end(
          JSON.stringify({
            error: {
              status: "UNAVAILABLE",
              message: "El servidor local no está disponible.",
            },
          }),
        );
      });
      siguiente.end(cuerpo);
    });
  },
);
servidor.listen(puerto, host, () =>
  console.log("Conexión TLS local de Functions preparada."),
);
for (const señal of ["SIGINT", "SIGTERM"])
  process.on(señal, () => servidor.close(() => process.exit()));
