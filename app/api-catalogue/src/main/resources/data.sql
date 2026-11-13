INSERT INTO produits (nom, categorie, prix) VALUES
    ('Clavier mécanique', 'Informatique', 89.90),
    ('Souris sans fil', 'Informatique', 34.50),
    ('Écran 27 pouces', 'Informatique', 249.00),
    ('Casque audio', 'Audio', 129.00),
    ('Webcam HD', 'Vidéo', 59.90)
ON CONFLICT (nom) DO NOTHING;
