package fr.gkefacile.catalogue;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.boot.availability.AvailabilityChangeEvent;
import org.springframework.boot.availability.LivenessState;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints de démonstration pour les leçons sur les probes et sur les logs.
 * À ne pas reproduire dans une vraie application.
 */
@RestController
@RequestMapping("/api/test")
public class TestController {

    private static final Logger log = LoggerFactory.getLogger(TestController.class);

    private final ApplicationEventPublisher publisher;

    public TestController(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    /** Fait échouer la liveness probe : Kubernetes va redémarrer le conteneur. */
    @PostMapping("/casser-liveness")
    public Map<String, String> casserLiveness() {
        AvailabilityChangeEvent.publish(publisher, this, LivenessState.BROKEN);
        return Map.of("liveness", "BROKEN");
    }

    /** Module 9 : écrit une erreur dans les logs et répond 500, pour s'entraîner à chercher. */
    @PostMapping("/erreur")
    public ResponseEntity<Map<String, String>> erreur() {
        log.error("Paiement refusé : le service de paiement ne répond pas");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("erreur", "paiement refusé"));
    }
}
