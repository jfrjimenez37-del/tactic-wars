// Sustituto mínimo de «apksigner» del Android SDK (sign/verify), basado en la librería apksig de Maven Central.
// Solo firma con el esquema v2 (Android 7.0 o superior): la firma v1 de apksig 2.3.0 usa clases internas
// del JDK que ya no existen en Java 21.
// Admite los argumentos con los que lo llama Godot: sign --ks K --ks-pass pass:P --ks-key-alias A [...] APK
import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;
import java.io.File;
import java.io.FileInputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class MiniApkSigner {
    public static void main(String[] args) throws Exception {
        if (args.length == 0) { System.err.println("uso: sign|verify ... apk"); System.exit(2); }
        if (args[0].equals("--version") || args[0].equals("version")) { System.out.println("0.9 (apksig 2.3.0)"); return; }
        String ks = null, pass = "", alias = null, keyPass = null;
        int minSdk = 24;
        for (int i = 1; i < args.length - 1; i++) {
            switch (args[i]) {
                case "--ks": ks = args[++i]; break;
                case "--ks-pass": pass = args[++i].replaceFirst("^pass:", ""); break;
                case "--key-pass": keyPass = args[++i].replaceFirst("^pass:", ""); break;
                case "--ks-key-alias": alias = args[++i]; break;
                case "--min-sdk-version": minSdk = Integer.parseInt(args[++i]); break;
                default: break;
            }
        }
        File apk = new File(args[args.length - 1]);
        if (args[0].equals("sign")) {
            KeyStore store = KeyStore.getInstance(KeyStore.getDefaultType());
            try (FileInputStream in = new FileInputStream(ks)) { store.load(in, pass.toCharArray()); }
            if (alias == null) alias = store.aliases().nextElement();
            PrivateKey key = (PrivateKey) store.getKey(alias, (keyPass != null ? keyPass : pass).toCharArray());
            List<X509Certificate> chain = new ArrayList<>();
            for (Certificate c : store.getCertificateChain(alias)) chain.add((X509Certificate) c);
            ApkSigner.SignerConfig cfg = new ApkSigner.SignerConfig.Builder("CERT", key, chain).build();
            File tmp = new File(apk.getPath() + ".signed");
            new ApkSigner.Builder(Collections.singletonList(cfg)).setInputApk(apk).setOutputApk(tmp)
                .setMinSdkVersion(minSdk).setV1SigningEnabled(false).setV2SigningEnabled(true).build().sign();
            Files.move(tmp.toPath(), apk.toPath(), StandardCopyOption.REPLACE_EXISTING);
            System.out.println("Signed");
        } else if (args[0].equals("verify")) {
            ApkVerifier.Result r = new ApkVerifier.Builder(apk).setMinCheckedPlatformVersion(24).build().verify();
            System.out.println("Verifies: " + r.isVerified() + " (v1 " + r.isVerifiedUsingV1Scheme() + ", v2 " + r.isVerifiedUsingV2Scheme() + ")");
            for (Object e : r.getErrors()) System.out.println("ERROR: " + e);
            System.exit(r.isVerified() ? 0 : 1);
        } else {
            System.exit(2);
        }
    }
}
