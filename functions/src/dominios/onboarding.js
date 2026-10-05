// Casos de uso del dominio; BancoBase conserva las escrituras monetarias compartidas.
import {
  falla,
  texto,
  identificador,
  referencia,
  numeroCuenta,
  huella,
  fechaLocal,
} from "../compartido.js";

export async function registrarCliente(banco, auth, d) {
  const uid = banco.actor(auth),
    nombres = texto(d.nombres, "tus nombres", 2, 28),
    apellidos = texto(d.apellidos, "tus apellidos", 2, 28);
  const correo = texto(d.correo, "tu correo", 5, 160).toLowerCase(),
    cedula = texto(d.cedula, "tu cédula", 10, 10);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo) || !/^\d{10}$/.test(cedula))
    falla("invalid-argument", "Revisa tu correo y tu cédula de 10 dígitos.");
  if (
    typeof auth.token?.email !== "string" ||
    auth.token.email.toLowerCase() !== correo
  )
    falla("permission-denied", "El correo debe corresponder a tu acceso.");
  if (d.aceptaContrato !== true || d.versionContrato !== "2026-10-v1")
    falla(
      "failed-precondition",
      "Lee y acepta el contrato y los términos antes de continuar.",
    );
  const domicilio = {
    direccion: texto(d.direccion, "tu dirección", 8, 180),
    ciudad: texto(d.ciudad, "tu ciudad", 2, 60),
    telefono: texto(d.telefono, "tu teléfono", 7, 20),
  };
  if (!/^[+\d ()-]+$/.test(domicilio.telefono))
    falla("invalid-argument", "Revisa tu teléfono.");
  const nombre = `${nombres} ${apellidos}`,
    fecha = banco.ahora(),
    c = banco.nuevaCuenta("ahorro", fecha);
  const identidadRef = banco.db.doc(
    `identidadesRegistradas/${huella([cedula])}`,
  );
  return banco.db.runTransaction(async (tx) => {
    const cRef = banco.cuenta(uid, "ahorros"),
      tarjetaRef = banco.privado(uid, "tarjetas", "bro_ahorros"),
      personalRef = banco.privado(uid, "datosPersonales", "identidad");
    const [anterior, identidad, perfil, tarjeta, personal, numero] =
      await Promise.all([
        tx.get(cRef),
        tx.get(identidadRef),
        tx.get(banco.usuario(uid)),
        tx.get(tarjetaRef),
        tx.get(personalRef),
        tx.get(banco.db.doc(`directorioCuentas/${c.numeroCuenta}`)),
      ]);
    if (anterior.exists && personal.data()?.contratoVersion === "2026-10-v1")
      return {
        cuenta: "ahorros",
        numero: anterior.data().numeroCuenta,
        nombre: perfil.data().nombre,
      };
    if (identidad.exists && identidad.data().uid !== uid)
      falla("already-exists", "Esta cédula ya está asociada a una cuenta.");
    if (!anterior.exists && numero.exists)
      falla("aborted", "Vuelve a intentar la apertura.");
    tx.set(banco.usuario(uid), {
      nombre,
      segmento: perfil.data()?.segmento ?? "equilibrio",
      mostrarSaldo: perfil.data()?.mostrarSaldo ?? true,
      actualizado: fecha,
    });
    if (!identidad.exists) tx.create(identidadRef, { uid, creado: fecha });
    tx.set(personalRef, {
      nombres,
      apellidos,
      nombre,
      correo,
      documento: cedula,
      domicilio,
      contratoVersion: "2026-10-v1",
      aceptado: fecha,
    });
    if (!anterior.exists) {
      tx.create(cRef, c);
      tx.create(banco.db.doc(`directorioCuentas/${c.numeroCuenta}`), {
        uid,
        cuenta: "ahorros",
        titular: nombre,
        tipo: "ahorro",
      });
    }
    const cuenta = anterior.exists ? anterior.data() : c;
    if (!tarjeta.exists)
      tx.create(tarjetaRef, {
        tipo: "propia",
        clase: "debito",
        cuenta: "ahorros",
        nombre: "Mi tarjeta de débito",
        banco: "FinanceBro",
        ultimos4: cuenta.tarjetaUltimos4,
        color: cuenta.color,
        personalizada: false,
        actualizado: fecha,
      });
    banco.avisarCliente(
      tx,
      uid,
      "bienvenida_ahorros",
      "Tu cuenta está lista",
      "Ya tienes tu cuenta de ahorros y tu tarjeta de débito digital.",
      "/tarjetas",
      fecha,
    );
    return { cuenta: "ahorros", numero: cuenta.numeroCuenta, nombre };
  });
}

export async function abrirAhorros(banco, auth, d) {
  const uid = banco.actor(auth),
    nombre = texto(d.nombre, "tu nombre", 2, 60);
  const telefono = texto(d.telefono, "tu teléfono", 7, 20),
    documento = texto(d.documento, "tu identificación", 6, 20);
  if (!/^[+\d ()-]+$/.test(telefono) || !/^[a-zA-Z0-9-]+$/.test(documento))
    falla("invalid-argument", "Revisa tus datos de identificación.");
  if (
    typeof d.nacimiento !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(d.nacimiento)
  )
    falla("invalid-argument", "Indica tu fecha de nacimiento.");
  const nacimiento = new Date(`${d.nacimiento}T12:00:00Z`);
  if (
    !Number.isFinite(nacimiento.getTime()) ||
    nacimiento.toISOString().slice(0, 10) !== d.nacimiento
  )
    falla("invalid-argument", "La fecha de nacimiento no es válida.");
  const hoy = fechaLocal(banco.reloj()),
    limite = `${Number(hoy.slice(0, 4)) - 18}${hoy.slice(4)}`;
  if (d.nacimiento > limite || d.nacimiento < "1900-01-01")
    falla("failed-precondition", "La apertura requiere ser mayor de edad.");
  if (d.aceptaTerminos !== true)
    falla(
      "failed-precondition",
      "Acepta el contrato y los términos de la cuenta.",
    );
  const fecha = banco.ahora(),
    c = banco.nuevaCuenta("ahorro", fecha);
  return banco.db.runTransaction(async (tx) => {
    const destino = banco.cuenta(uid, "ahorros"),
      existente = await tx.get(destino);
    if (existente.exists)
      return { cuenta: "ahorros", numero: existente.data().numeroCuenta };
    const directorio = banco.db.doc(`directorioCuentas/${c.numeroCuenta}`),
      ocupado = await tx.get(directorio),
      perfil = await tx.get(banco.usuario(uid));
    if (ocupado.exists) falla("aborted", "Vuelve a intentar la apertura.");
    if (!perfil.exists)
      falla(
        "failed-precondition",
        "Completa tu perfil antes de abrir una cuenta.",
      );
    tx.create(destino, c);
    tx.create(banco.privado(uid, "tarjetas", "bro_ahorros"), {
      tipo: "propia",
      clase: "debito",
      personalizada: false,
      cuenta: "ahorros",
      nombre: "Mi FinanceBro",
      banco: "FinanceBro",
      ultimos4: c.tarjetaUltimos4,
      color: c.color,
      actualizado: fecha,
    });
    tx.create(directorio, {
      uid,
      cuenta: "ahorros",
      titular: nombre,
      tipo: "ahorro",
    });
    tx.set(banco.privado(uid, "datosPersonales", "identidad"), {
      nombre,
      telefono,
      documento,
      nacimiento: d.nacimiento,
      terminos: "demostracion-2026-10",
      aceptado: fecha,
    });
    return { cuenta: "ahorros", numero: c.numeroCuenta };
  });
}

export async function migrarCuentas(banco, auth, d) {
  banco.actor(auth, true);
  const uid = identificador(d.uid);
  const perfil = await banco.usuario(uid).get();
  if (!perfil.exists) falla("not-found", "No encontramos a la persona.");
  const cuentas = await banco.usuario(uid).collection("cuentas").get();
  for (const snapshot of cuentas.docs) {
    const propuesta = banco.nuevaCuenta("ahorro", banco.ahora());
    await banco.db.runTransaction(async (tx) => {
      const actual = await tx.get(snapshot.ref);
      if (!actual.exists) return;
      const anterior = actual.data();
      const numero = anterior.numeroCuenta ?? propuesta.numeroCuenta;
      const tipo = anterior.tipo ?? propuesta.tipo;
      const directorio = banco.db.doc(`directorioCuentas/${numero}`);
      const ocupado = await tx.get(directorio);
      const tarjetaRef = banco.privado(uid, "tarjetas", `bro_${snapshot.id}`);
      const tarjeta = await tx.get(tarjetaRef);
      if (
        ocupado.exists &&
        (ocupado.data().uid !== uid || ocupado.data().cuenta !== snapshot.id)
      ) {
        falla("aborted", "Reintenta la preparación.");
      }
      if (!anterior.numeroCuenta)
        tx.update(snapshot.ref, {
          numeroCuenta: numero,
          tipo,
          estado: "activa",
          color: anterior.color ?? propuesta.color,
        });
      if (!ocupado.exists)
        tx.create(directorio, {
          uid,
          cuenta: snapshot.id,
          titular: perfil.data().nombre,
          tipo,
        });
      if (!tarjeta.exists && tipo !== "corriente" && anterior.tarjetaUltimos4)
        tx.create(tarjetaRef, {
          tipo: "propia",
          cuenta: snapshot.id,
          nombre: anterior.nombre,
          banco: "FinanceBro",
          ultimos4: anterior.tarjetaUltimos4,
          color: anterior.color ?? propuesta.color,
          actualizado: banco.ahora(),
        });
    });
    // Una interrupción puede dejar páginas pendientes; reintentar completa
    // el histórico sin reemplazar registros existentes ni resetear saldos.
    const historial = await snapshot.ref.collection("movimientos").get();
    for (const m of historial.docs) {
      try {
        await banco
          .privado(uid, "movimientosGlobales", `${snapshot.id}_${m.id}`)
          .create({
            ...m.data(),
            referencia: m.data().referencia ?? m.id,
            uid,
            cuenta: snapshot.id,
          });
      } catch (error) {
        if (error.code !== 6 && error.code !== "already-exists") throw error;
      }
    }
  }
  return { preparadas: cuentas.size };
}
