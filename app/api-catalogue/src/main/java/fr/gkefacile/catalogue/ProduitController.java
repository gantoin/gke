package fr.gkefacile.catalogue;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ProduitController {

    private static final List<Produit> PRODUITS = List.of(
            new Produit(1, "Clavier mécanique", "Informatique", new BigDecimal("89.90")),
            new Produit(2, "Souris sans fil", "Informatique", new BigDecimal("34.50")),
            new Produit(3, "Écran 27 pouces", "Informatique", new BigDecimal("249.00")),
            new Produit(4, "Casque audio", "Audio", new BigDecimal("129.00")),
            new Produit(5, "Webcam HD", "Vidéo", new BigDecimal("59.90")));

    private final String version;
    private final String pod;

    public ProduitController(@Value("${APP_VERSION:v1}") String version) {
        this.version = version;
        // Dans Kubernetes, HOSTNAME contient le nom du pod.
        this.pod = System.getenv().getOrDefault("HOSTNAME", "inconnu");
    }

    @GetMapping("/produits")
    public ResponseEntity<List<Produit>> produits() {
        return ResponseEntity.ok()
                .header("X-Pod-Name", pod)
                .body(PRODUITS);
    }

    @GetMapping("/info")
    public Map<String, String> info() {
        return Map.of(
                "application", "api-catalogue",
                "version", version,
                "pod", pod);
    }
}
