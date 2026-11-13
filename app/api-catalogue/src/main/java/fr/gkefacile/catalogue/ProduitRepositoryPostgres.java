package fr.gkefacile.catalogue;

import java.math.BigDecimal;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Les produits sont rangés dans PostgreSQL (module 6). La table est créée par schema.sql au démarrage. */
@Repository
@Profile("postgres")
public class ProduitRepositoryPostgres implements ProduitRepository {

    private final JdbcTemplate jdbc;

    public ProduitRepositoryPostgres(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public List<Produit> tous() {
        return jdbc.query("SELECT id, nom, categorie, prix FROM produits ORDER BY id",
                (rs, i) -> new Produit(rs.getLong("id"), rs.getString("nom"), rs.getString("categorie"), rs.getBigDecimal("prix")));
    }

    @Override
    public Produit ajouter(String nom, String categorie, BigDecimal prix) {
        Long id = jdbc.queryForObject(
                "INSERT INTO produits (nom, categorie, prix) VALUES (?, ?, ?) RETURNING id", Long.class, nom, categorie, prix);
        return new Produit(id, nom, categorie, prix);
    }

    @Override
    public String stockage() {
        return "postgresql";
    }
}
