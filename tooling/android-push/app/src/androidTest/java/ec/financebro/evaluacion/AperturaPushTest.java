package ec.financebro.evaluacion;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject2;
import androidx.test.uiautomator.Until;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Verifica la interacción con Android; no envía ni fabrica mensajes de FCM. */
@RunWith(AndroidJUnit4.class)
public class AperturaPushTest {
    @Test public void abrirAvisoRealDelSistema() throws Exception {
        UiDevice dispositivo = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        assertTrue("No se abrió el panel de notificaciones", dispositivo.openNotification());
        UiObject2 aviso = dispositivo.wait(Until.findObject(
            By.text("Tu prioridad importa. Revisa tus preferencias.")), 15000);
        assertNotNull("No se encontró el push recibido por Android", aviso);
        // Pausa para que el aviso recibido sea legible en la grabación funcional.
        Thread.sleep(2500);
        aviso.click();
        assertTrue("El aviso no abrió FinanceBro", dispositivo.wait(
            Until.hasObject(By.pkg("ec.financebro.financebro")), 15000));
    }
}
