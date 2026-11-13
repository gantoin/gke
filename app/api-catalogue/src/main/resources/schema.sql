CREATE TABLE IF NOT EXISTS produits (
    id        BIGSERIAL PRIMARY KEY,
    nom       VARCHAR(200) NOT NULL UNIQUE,
    categorie VARCHAR(100) NOT NULL,
    prix      NUMERIC(10, 2) NOT NULL
);
