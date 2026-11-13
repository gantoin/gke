package fr.gkefacile.catalogue;

import java.math.BigDecimal;
import java.util.List;

/** Là où sont rangés les produits : en mémoire par défaut, dans PostgreSQL avec le profil "postgres". */
public interface ProduitRepository {

    List<Produit> tous();

    Produit ajouter(String nom, String categorie, BigDecimal prix);

    /** "memoire" ou "postgresql", affiché par /api/info. */
    String stockage();
}
