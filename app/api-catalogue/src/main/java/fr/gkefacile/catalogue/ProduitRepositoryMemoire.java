package fr.gkefacile.catalogue;

import java.math.BigDecimal;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

/** Les produits sont gardés en mémoire : ils sont perdus à chaque redémarrage du pod. */
@Repository
@Profile("!postgres")
public class ProduitRepositoryMemoire implements ProduitRepository {

    private final List<Produit> produits = new CopyOnWriteArrayList<>(List.of(
            new Produit(1, "Clavier mécanique", "Informatique", new BigDecimal("89.90")),
            new Produit(2, "Souris sans fil", "Informatique", new BigDecimal("34.50")),
            new Produit(3, "Écran 27 pouces", "Informatique", new BigDecimal("249.00")),
            new Produit(4, "Casque audio", "Audio", new BigDecimal("129.00")),
            new Produit(5, "Webcam HD", "Vidéo", new BigDecimal("59.90"))));

    @Override
    public List<Produit> tous() {
        return produits;
    }

    @Override
    public synchronized Produit ajouter(String nom, String categorie, BigDecimal prix) {
        Produit produit = new Produit(produits.size() + 1, nom, categorie, prix);
        produits.add(produit);
        return produit;
    }

    @Override
    public String stockage() {
        return "memoire";
    }
}
