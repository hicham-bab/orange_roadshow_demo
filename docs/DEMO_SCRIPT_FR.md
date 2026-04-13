# Script Demo — Orange Roadshow

**Entreprise fictive :** Harmony Music
**Duree totale :** ~20 minutes
**Message central :** dbt est la couche d'intelligence entre vos donnees et l'IA. Sans elle, l'IA repond avec assurance... mais elle a tort.

**Contexte :** Vous passez apres votre collegue Snowflake qui vient de montrer Cortex Analyst sur les donnees brutes et d'obtenir des reponses fausses/incoherentes. Vous reprenez la main.

---

## Donnees

| Couche | Schema Snowflake | Description |
|--------|-----------------|-------------|
| Brute (Fivetran) | `HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL` | Tables brutes, SCD2, epochs, JSON |
| Gouvernee (dbt) | `HICHAMB_FIVETRAN_DEMO.MARTS` | Marts dbt avec contrats, tests, semantic layer |

---

## Preparation (avant la demo)

Onglets ouverts :
1. **Streamlit** — en mode "Raw Data", question pre-tapee
2. **dbt Cloud** — Explorer avec le DAG
3. **dbt Cloud** — Semantic Layer / metrics
4. **Snowflake Worksheets** — pour requetes ad-hoc si besoin

---

## TRANSITION — Reprise apres le collegue Snowflake (~2 min)

*Le collegue Snowflake vient de montrer Cortex Analyst sur les donnees brutes. Les reponses etaient fausses.*

> "Merci [prenom du collegue]. On vient de voir quelque chose de tres revelateur. Cortex Analyst est un outil puissant — il genere du SQL, il comprend le langage naturel. Mais on vient de voir qu'il a donne des reponses fausses. Pas parce que l'IA est mauvaise — mais parce que les donnees qu'on lui a donnees ne sont pas pretes."
>
> "Le pipeline Fivetran a fait son travail parfaitement. Chaque ligne, chaque table, tout est la dans Snowflake. Mais des donnees deplacees, ce n'est pas des donnees pretes pour l'analytique. Il manque une couche entre l'ingestion et la consommation. C'est cette couche que je vais vous montrer."

---

## ACTE 1 — "Pourquoi ca ne marche pas" (~3 min)

*Rappel rapide des problemes observes. Si le collegue a deja montre les echecs, aller vite ici — c'est un recap.*

> "Revenons sur ce qu'on a vu. Quatre problemes concrets :"

**1. Pas de colonne revenu**
> "La table `SALES_ORDERS` n'a pas de colonne revenu. Les produits sont dans un champ texte JSON brut — `ORDERED_PRODUCTS`. L'IA ne peut pas calculer le chiffre d'affaires a partir d'un blob JSON."

**2. SCD2 = comptage double**
> "La table `CUSTOMERS` est une table SCD2 — historique des changements. 28 000 lignes, mais seulement ~10 000 clients reels. L'IA compte des versions de clients, pas des clients."

**3. Dates en epoch Unix**
> "`ORDER_DATETIME` est stocke comme un nombre — un timestamp Unix. L'IA le traite comme un entier. Tout filtre temporel donne un resultat absurde."

**4. Segments de fidelite = numeros bruts**
> "Le segment de fidelite est un `3`, pas un `Gold`. Sans la jointure avec la table de reference, le metier ne comprend rien."

*Pause.*

> "Meme IA. Memes donnees dans Snowflake. Le probleme, c'est ce qui manque entre les deux. Et c'est exactement la que dbt intervient."

---

## ACTE 2 — "dbt : la couche d'intelligence" (~10 min)

**Ouvrir dbt Cloud Explorer — vue DAG.**

> "Voici notre projet dbt pour Harmony Music. Les memes donnees Snowflake — transformees, testees, documentees."

---

### 2.1 — Le DAG et les couches (~3 min)

**Pointer vers le staging :**
> "Premiere couche : le staging. Un modele par table source. C'est ici qu'on fait le menage :
> - `stg_sales_orders` : l'epoch devient une vraie DATE, le JSON est parse avec TRY_PARSE_JSON
> - `stg_customers` : les epochs SCD2 deviennent des dates, on identifie le record courant
> - `stg_loyalty_segments` : la table de reference, propre et prete a etre jointe"

**Pointer vers les intermediaires :**
> "Deuxieme couche : les modeles intermediaires. C'est la que la logique metier prend forme."

> "`int_current_customers` — le modele le plus important. La table source est SCD2, avec plusieurs lignes par client. Ce modele resout ca : une seule ligne par `customer_id`, le record courant. Et il joint le segment de fidelite — `3` devient `Gold`."

> "`int_sales_order_lines` — ici on explose le JSON `ORDERED_PRODUCTS` : une ligne par article, avec le nom du produit, la quantite, le prix unitaire. C'est ici que le revenu nait. Il n'existe pas dans le systeme source — c'est dbt qui le cree."

**Pointer vers les marts :**
> "Troisieme couche : les marts. `dim_customers`, `fct_sales_orders`, `dim_b2b_customers`, `fct_b2b_orders`. C'est ce que l'IA va consommer."

---

### 2.2 — Contrats et tests (~2 min)

**Ouvrir `_core_models.yml` — montrer les contrats :**
> "Chaque mart a un contrat. Si quelqu'un supprime `total_revenue` ou change son type, le build echoue. C'est une garantie : l'interface entre l'equipe data et les consommateurs est stable."

**Montrer les tests :**
> "Et derriere, des tests :
> - `customer_id` est unique dans `dim_customers` — la resolution SCD2 est validee
> - `total_revenue` est positif
> - Chaque commande a un client valide
>
> Si la resolution SCD2 casse, le test `assert_no_duplicate_current_customers` echoue et le pipeline s'arrete. On ne deploie pas de donnees cassees."

---

### 2.3 — Semantic Layer (~2 min)

**Naviguer vers les metriques dans dbt Cloud :**
> "Maintenant, la Semantic Layer. Les metriques sont definies une seule fois, dans le code :
> - `total_b2c_revenue` : somme du revenu derive du JSON parse
> - `avg_b2c_order_value` : revenu moyen par commande
> - `b2b_cancellation_rate` : proportion du revenu B2B annule
> - `total_customers` : nombre de clients actifs, SCD2 resolu
>
> Versionne. Teste. Disponible pour Tableau, Hex, Google Sheets, Cortex — tout le monde obtient la meme reponse. Une seule definition, partout."

> "Et c'est la la difference cle. Sans cette couche semantique, si vous posez la meme question a deux outils differents, vous obtenez deux reponses differentes. L'un calcule le revenu d'une facon, l'autre d'une autre. La Semantic Layer garantit la coherence."

---

### 2.4 — Semantic Views dans dbt (~2 min)

> "Et maintenant quelque chose de nouveau. On peut definir les Semantic Views de Snowflake directement dans dbt."

**Ouvrir `models/semantic_views/cortex_dbt_sv.sql` :**
> "Regardez : c'est un modele dbt avec `materialized='semantic_view'`. On definit les tables, les relations, les facts, les dimensions — avec les synonymes, les commentaires, tout le contexte que Cortex Analyst a besoin pour generer du SQL correct."

> "L'avantage ? Cette semantic view est dans le meme repo que les modeles qu'elle decrit. Elle est versionnee, elle passe par la CI, elle evolue avec les transformations. Si je renomme une colonne dans mon mart, la semantic view est mise a jour dans le meme commit. Pas de drift."

> "Avant, on devait maintenir ces vues en dehors de dbt, avec du SQL brut. Maintenant, tout est au meme endroit. dbt ne se contente pas de transformer les donnees — il gouverne aussi la facon dont l'IA les consomme."

---

### 2.5 — dbt Mesh (~1 min)

**Montrer le DAG cross-projet dans dbt Cloud :**
> "Dernier point : dbt Mesh. Chez Harmony Music, l'equipe data platform maintient les marts core avec des contrats. Mais d'autres equipes consomment ces modeles."

> "L'equipe Marketing a son propre projet dbt. Elle consomme `dim_customers` et `fct_sales_orders` via une reference cross-projet — `ref('fretwork_guitars', 'dim_customers')` — pour construire ses segments de campagne et ses analyses regionales. Sans dupliquer la logique, sans redefinir le revenu."

> "L'equipe Finance fait pareil : elle consomme les marts B2C et B2B pour consolider le revenu et evaluer le risque des comptes B2B. Un seul contrat, une seule definition du revenu, et chaque equipe avance en autonomie."

> "C'est ca dbt Mesh : des equipes autonomes qui construisent sur des fondations gouvernees."

---

## ACTE 3 — "IA + dbt = Confiance" (~5 min)

**Basculer Streamlit en mode "dbt Marts".**

> "Memes questions. Meme IA. Donnees differentes."

---

**Question 1 : "What was our total revenue last month?"**

*Cortex retourne un montant en dollars, filtre correctement par date.*

> "Le revenu est maintenant une colonne a part entiere — derivee des lignes de commande parsees, avec une definition claire : somme de quantite fois prix unitaire, par commande. Un seul chiffre. Une seule definition."

---

**Question 2 : "How many customers do we have by loyalty tier?"**

*Reponse : Gold: 4 200, Platinum: 1 100, Silver: 8 300, Bronze: 15 200*

> "On voit Gold, Silver, Platinum — pas 3, 2, 1. Et le comptage est correct parce que la table SCD2 a ete resolue : une seule ligne par client. dbt a fait la deduplication, la jointure, la transformation."

---

**Question 3 : "Which region has the most B2C orders in the last 6 months?"**

*Filtre temporel correct parce que `order_date` est un vrai DATE.*

> "Le filtre temporel fonctionne parce que l'epoch a ete converti en date au staging. C'est pour ca que la transformation n'est pas optionnelle."

---

**Question 4 (optionnelle, si le temps le permet) : "Which B2B accounts are at risk?"**

*Retourne les comptes avec health_status = 'at_risk'.*

> "Le health score et le statut de risque sont calcules par dbt a partir des tickets, des retours, du volume de commandes. L'IA n'a pas besoin de deviner — le contexte metier est deja dans les donnees."

---

*Conclusion :*

> "Meme Cortex Analyst. Memes donnees dans Snowflake. Des reponses radicalement differentes. La difference, c'est la couche entre l'ingestion brute et la consommation par l'IA — c'est dbt."
>
> "Fivetran deplace les donnees. Snowflake les stocke. Mais sans dbt au milieu, l'IA se trompe — a chaque fois."
>
> "Et avec la Semantic Layer, Tableau, Hex, Google Sheets et Cortex obtiennent tous la meme reponse. Une seule definition, partout, versionnee, testee. C'est ce que ca veut dire quand on dit que dbt est essentiel dans un monde IA."
>
> "dbt n'est pas juste un outil de transformation. C'est la couche d'intelligence de votre data stack."

---

## Points cles par acte

| Acte | Point | Phrase choc |
|------|-------|-------------|
| 1 | Pas de revenu | "ORDERED_PRODUCTS est un blob JSON. L'IA ne peut pas calculer de revenu a partir de texte brut." |
| 1 | SCD2 | "Ce ne sont pas 28K clients — ce sont 28K versions de clients." |
| 1 | Epochs | "ORDER_DATETIME est un nombre, pas une date. Les filtres temporels sont absurdes." |
| 1 | Segments | "Segment 3 ne veut rien dire sans la jointure. dbt fait cette jointure." |
| 2 | Parsing | "dbt cree le revenu a partir du JSON. Il n'existe pas dans la source." |
| 2 | SCD2 | "int_current_customers : un client, une ligne. Point." |
| 2 | Contrats | "Si le schema casse, le build echoue. Pas de surprise en production." |
| 2 | Semantic Layer | "Sans semantic layer, deux outils, deux reponses. Avec, une seule verite." |
| 2 | Semantic Views | "La semantic view est dans le meme repo que le modele. Zero drift." |
| 2 | Mesh | "Equipes autonomes, fondations gouvernees." |
| 3 | Confiance | "Gold, pas 3. Une date, pas un epoch. Du revenu, pas du null." |

---

## Questions anticipees

**"Cortex Analyst ne peut pas parser le JSON lui-meme ?"**
> "Il peut essayer — mais il ne connait pas vos regles metier. Quels champs sont du revenu ? Qu'en est-il des commandes annulees ? Et si le format JSON change ? dbt encode ces decisions dans du SQL versionne et teste. Cortex consomme le resultat."

**"Pourquoi ne pas corriger le schema source dans PostgreSQL ?"**
> "ORDERED_PRODUCTS en JSON est un choix de design legitime — flexible pour un catalogue produit varie. Le SCD2 est intentionnel pour l'audit. Le systeme source est fait pour les transactions, pas pour l'analytique. C'est exactement pour ca que la couche de transformation existe."

**"Qu'est-ce que dbt apporte qu'une stored procedure ne pourrait pas ?"**
> "Les tests, la documentation, le lineage, le version control, la Semantic Layer, et maintenant les Semantic Views. Une stored procedure peut transformer des donnees — elle ne peut pas vous dire quel outil IA consomme quelle metrique, ni vous alerter quand un changement de schema casse une hypothese."

**"Pourquoi definir les semantic views dans dbt et pas directement dans Snowflake ?"**
> "Parce que la semantic view decrit des modeles dbt. Si elle vit en dehors du repo, elle derive — quelqu'un renomme une colonne, la vue casse en silence. Dans dbt, la vue evolue avec le modele, dans le meme commit, testee par la meme CI."

**"C'est quoi dbt Mesh exactement ?"**
> "C'est la capacite de partager des modeles entre projets dbt de facon gouvernee. L'equipe core expose des modeles publics avec un contrat. L'equipe marketing ou finance les consomme via ref cross-projet. Chaque equipe a son propre projet, ses propres deploiements, mais des definitions communes."

**"Et la Semantic Layer vs les Semantic Views, c'est quoi la difference ?"**
> "La Semantic Layer dbt, c'est MetricFlow — des metriques definies dans le code, exposees via API a n'importe quel outil (Tableau, Hex, Sheets). Les Semantic Views Snowflake, c'est le format que Cortex Analyst comprend pour generer du SQL. Les deux se completent : on definit les metriques dans la Semantic Layer pour la coherence multi-outil, et on publie les semantic views pour que Cortex ait le contexte dont il a besoin."
