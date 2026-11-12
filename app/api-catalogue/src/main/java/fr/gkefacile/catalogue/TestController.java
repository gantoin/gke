package fr.gkefacile.catalogue;

import java.util.Map;

import org.springframework.boot.availability.AvailabilityChangeEvent;
import org.springframework.boot.availability.LivenessState;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints de démonstration pour la leçon sur les probes.
 * À ne pas reproduire dans une vraie application.
 */
@RestController
@RequestMapping("/api/test")
public class TestController {

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
}
