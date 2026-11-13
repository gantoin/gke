package fr.gkefacile.catalogue;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ProduitController {

    /** Ce qu'on envoie pour ajouter un produit. */
    public record NouveauProduit(String nom, String categorie, BigDecimal prix) {
    }

    private final ProduitRepository repository;
    private final String version;
    private final String pod;

    public ProduitController(ProduitRepository repository, @Value("${APP_VERSION:v1}") String version) {
        this.repository = repository;
        this.version = version;
        // Dans Kubernetes, HOSTNAME contient le nom du pod.
        this.pod = System.getenv().getOrDefault("HOSTNAME", "inconnu");
    }

    @GetMapping("/produits")
    public ResponseEntity<List<Produit>> produits() {
        return ResponseEntity.ok()
                .header("X-Pod-Name", pod)
                .body(repository.tous());
    }

    @PostMapping("/produits")
    public ResponseEntity<Produit> ajouter(@RequestBody NouveauProduit nouveau) {
        Produit produit = repository.ajouter(nouveau.nom(), nouveau.categorie(), nouveau.prix());
        return ResponseEntity.status(HttpStatus.CREATED)
                .header("X-Pod-Name", pod)
                .body(produit);
    }

    @GetMapping("/info")
    public Map<String, String> info() {
        return Map.of(
                "application", "api-catalogue",
                "version", version,
                "stockage", repository.stockage(),
                "pod", pod);
    }
}
