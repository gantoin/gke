package fr.gkefacile.catalogue;

import java.math.BigDecimal;

public record Produit(long id, String nom, String categorie, BigDecimal prix) {
}
