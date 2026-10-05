import { createHash } from "node:crypto";
import { createReadStream, createWriteStream } from "node:fs";
import { access, mkdir, readFile, rename, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { fileURLToPath } from "node:url";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const destino = resolve(
  process.argv[2] ?? `${raiz}/admin/public/presentacion/videos`,
);
const base =
  "https://github.com/CodeArtNexus/financebro-flutter/releases/download/v1.7.0-audiovisual/";
const archivos = JSON.parse(
  await readFile(
    `${raiz}/admin/public/presentacion/exportaciones.json`,
    "utf8",
  ),
);
await mkdir(destino, { recursive: true });

async function huella(archivo) {
  const hash = createHash("sha256");
  for await (const bloque of createReadStream(archivo)) hash.update(bloque);
  return hash.digest("hex");
}

for (const { archivo, sha256 } of archivos) {
  if (
    !/^[A-Za-z][A-Za-z0-9-]+\.mp4$/.test(archivo) ||
    !/^[a-f0-9]{64}$/.test(sha256)
  ) {
    throw new Error("El manifiesto de videos contiene una entrada no válida.");
  }
  const final = resolve(destino, archivo);
  const existe = await access(final).then(
    () => true,
    () => false,
  );
  if (existe) {
    if ((await huella(final)) !== sha256) {
      throw new Error(
        `El archivo ${archivo} difiere de la entrega. Conservar o retirar esa copia antes de continuar.`,
      );
    }
    console.log(`Video verificado: ${archivo}`);
    continue;
  }
  const temporal = `${final}.descarga-${process.pid}.mp4`;
  try {
    const respuesta = await fetch(`${base}${archivo}`, {
      signal: AbortSignal.timeout(600_000),
    });
    if (!respuesta.ok || !respuesta.body)
      throw new Error(
        `No se pudo descargar ${archivo}: HTTP ${respuesta.status}.`,
      );
    await pipeline(
      Readable.fromWeb(respuesta.body),
      createWriteStream(temporal, { flags: "wx" }),
    );
    if ((await huella(temporal)) !== sha256)
      throw new Error(
        `La descarga de ${archivo} no coincide con la huella de la entrega.`,
      );
    await rename(temporal, final);
    console.log(`Video descargado y verificado: ${archivo}`);
  } finally {
    await rm(temporal, { force: true });
  }
}
