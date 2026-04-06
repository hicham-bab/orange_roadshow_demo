# Script de Démo : Données Prêtes pour l'IA avec Fivetran + dbt + Snowflake
## "Avant que l'IA puisse répondre, vous devez pouvoir lui faire confiance"

**Audience :** Prospects Snowflake ayant assisté à une démo Cortex / Fonctionnalités IA
**Durée :** ~20 minutes
**Message clé :** L'IA n'est aussi bonne que ce qui se trouve en dessous. Snowflake peut interroger vos données — mais pouvez-vous auditer, faire confiance et expliquer la réponse ?

---

## Le Contexte : Une Question Provocatrice

> "L'équipe Snowflake vient de vous montrer une IA qui répond à des questions métier. Avant d'investir là-dedans, permettez-moi de vous poser une question :
> **Si Cortex vous dit que le chiffre d'affaires a augmenté de 12% ce mois-ci — comment savez-vous que c'est vrai ?**
> D'où vient ce chiffre ? Quand les données ont-elles été mises à jour pour la dernière fois ? Ont-elles été testées ?
> Si vous ne pouvez pas répondre à ces trois questions, la réponse de l'IA est sans valeur — ou pire, dangereuse."

Cette démo montre comment Fivetran + dbt rend vos données **prêtes pour l'IA** : fraîches, testées, définies, et entièrement auditables depuis la question jusqu'à la ligne source.

---

## ACTE 1 : La Source — "D'où viennent les données ?"

### Ce qu'il faut montrer : le tableau de bord Fivetran (vos captures d'écran)

**Points clés :**
- "Les données partent d'une base PostgreSQL sur Google Cloud — votre système opérationnel."
- "Fivetran les transfère vers Snowflake toutes les 6 heures, automatiquement."
- Pointer le journal de synchronisation : `6 avr. 16h41 — 1m 15s — Synchronisation réussie`
- "Chaque synchronisation est journalisée. Vous voyez exactement quand les données sont arrivées : date, heure, durée, lignes chargées."
- Pointer l'onglet Schema : "6 tables, toutes sélectionnées, mode suppression douce — ce qui signifie qu'on ne perd jamais l'historique."

**La piste d'audit ajoutée par Fivetran :**
Fivetran ajoute deux colonnes à chaque ligne synchronisée :

| Colonne | Signification |
|---------|--------------|
| `_fivetran_synced` | Horodatage exact de la dernière synchronisation de cette ligne depuis la source |
| `_fivetran_deleted` | True si la ligne source a été supprimée (suppression douce — on conserve l'historique) |

> "C'est votre chaîne de custody au niveau de l'ingestion. Vous pouvez toujours répondre : *quand cette ligne est-elle arrivée dans Snowflake ?*"

**À montrer dans Snowflake :**
```sql
SELECT
    customer_id,
    customer_name,
    loyalty_segment,
    _fivetran_synced,
    _fivetran_deleted
FROM HICHAMB_FIVETRAN_DEMO.retail.customers
ORDER BY _fivetran_synced DESC
LIMIT 10;
```

Souligner : chaque ligne a un horodatage de synchronisation. Aucune ligne n'arrive sans.

---

## ACTE 2 : Fraîcheur — "Les données sont-elles à jour en ce moment ?"

### Ce qu'il faut montrer : dbt source freshness

```bash
cd ~/retail-fivetran-demo
dbt source freshness
```

**Résultat attendu :**
```
Found 6 sources, configured with freshness
  customers .............. PASS  [0h 25m ago]
  loyalty_segments ....... PASS  [0h 25m ago]
  ret_customers .......... PASS  [0h 25m ago]
  ret_orders ............. PASS  [0h 25m ago]
  ret_tickets ............ PASS  [0h 25m ago]
  sales_orders ........... PASS  [0h 25m ago]
```

**Points clés :**
- "dbt exécute cette vérification automatiquement avant toute transformation. Si les données sont périmées, on le sait avant de construire les modèles."
- Ouvrir `models/staging/fivetran_retail/_sources.yml`, faire défiler jusqu'au bloc freshness :

```yaml
freshness:
  warn_after: {count: 7, period: hour}
  error_after: {count: 13, period: hour}
```

- "Fivetran synchronise toutes les 6 heures. On avertit à 7 heures, erreur à 13. Si Fivetran a un incident, dbt le détecte avant que l'IA ne voie des données périmées."
- "Sans ça, Cortex pourrait répondre à des questions sur les données d'hier sans que vous le sachiez."

> **Question d'audit répondue :** *Quand ces données ont-elles été rafraîchies pour la dernière fois ?*
> **Réponse :** `_fivetran_synced` au niveau de la ligne + fraîcheur dbt au niveau de la source.

---

## ACTE 3 : Qualité des Données — "Peut-on faire confiance au contenu ?"

### Ce qu'il faut montrer : les tests dbt

```bash
dbt test --select staging
```

**Points clés :**
- "Avant que quoi que ce soit n'atteigne les marts interrogés par l'IA, on exécute plus de 40 assertions."
- Ouvrir `_sources.yml` et parcourir des exemples pendant l'exécution des tests :

**Non nul / Unicité (exactitude) :**
```yaml
- name: id
  tests:
    - unique
    - not_null
- name: order_user_id
  tests:
    - not_null   # chaque commande doit avoir un client
```

**Valeurs acceptées (intégrité du domaine) :**
```yaml
- name: status
  tests:
    - accepted_values:
        values: ['completed', 'cancelled', 'pending', 'processing', 'refunded']
```

- "Si un nouveau statut apparaît dans la source — par exemple, l'équipe dev ajoute `'on_hold'` — ce test échoue. On le sait avant l'IA."
- "Sans tests, l'IA pourrait calculer un taux d'annulation auquel manquent 15% des annulations parce que le libellé du statut a changé."

**Montrer le filtre de la couche staging dans n'importe quel SQL de staging :**
```sql
WHERE _fivetran_deleted IS DISTINCT FROM TRUE
```
- "On ne remonte jamais les lignes supprimées vers la couche de transformation. Fivetran suit les suppressions ; dbt les respecte."

> **Question d'audit répondue :** *Ces données sont-elles correctes et complètes ?*
> **Réponse :** Plus de 40 assertions, exécutées à chaque pipeline, avant que les données n'atteignent un mart.

---

## ACTE 4 : Lignage — "Comment ce chiffre a-t-il été calculé ?"

### Ce qu'il faut montrer : le graphe de lignage dbt docs

```bash
dbt docs generate
dbt docs serve
```

Ouvrir le navigateur, naviguer jusqu'au graphe de lignage de `fct_orders`. Parcourir le graphe :

```
[source: retail.sales_orders]     [source: retail.ret_orders]
         |                                    |
[stg_sales_orders]              [stg_ret_orders]
         |                                    |
         |                    [int_ret_orders_with_customers]
         |                                    |
         +---------------+--------------------+
                         |
                    [fct_orders]
                         |
              [modèle sémantique: orders]
                         |
                  [métrique: total_revenue]
```

**Points clés :**
- "Chaque métrique a un lignage complet. Cliquer sur `total_revenue` → pointe vers `fct_orders.order_amount` → qui vient soit de `stg_ret_orders.amount` (B2B), soit est null (commandes B2C comptées, pas valorisées)."
- "Cliquer sur `stg_ret_orders` → vient de `source: fivetran_retail.ret_orders` → synchronisé depuis PostgreSQL via Fivetran."
- "Un analyste, un régulateur, ou votre DAF peut tracer n'importe quel chiffre jusqu'à la ligne brute dans la base de données source."

> **Question d'audit répondue :** *Comment ce chiffre a-t-il été calculé ?*
> **Réponse :** Lignage DAG complet, descriptions au niveau des colonnes, documentation modèle par modèle.

---

## ACTE 5 : Couche Sémantique — "Que signifie réellement cette métrique ?"

### Ce qu'il faut montrer : semantic_models.yml et metrics.yml

Ouvrir `models/marts/semantic_models.yml`. Parcourir le modèle sémantique `orders` :

```yaml
- name: orders
  model: ref('fct_orders')
  entities:
    - name: order
      type: primary
      expr: order_key
    - name: customer
      type: foreign
      expr: customer_id
  dimensions:
    - name: order_date
      type: time
      time_granularity: day
    - name: order_type      # 'b2b' ou 'b2c'
    - name: order_status
    - name: region
  measures:
    - name: total_revenue
      expr: order_amount
      agg: sum
    - name: order_count
      expr: order_key
      agg: count_distinct
    - name: cancelled_order_count
      expr: "case when order_status = 'cancelled' then 1 else 0 end"
      agg: sum
```

**Points clés :**
- "C'est là que vit la définition métier. `total_revenue` est *explicitement* `sum(order_amount)`. Pas déduit. Pas halluciné."
- "Quand Snowflake Cortex interroge votre entrepôt directement, il voit des noms de colonnes et devine leur signification. Ici, on la définit."
- Ouvrir `metrics.yml` :

```yaml
- name: cancellation_rate
  type: ratio
  type_params:
    numerator: cancelled_order_count
    denominator: order_count

- name: revenue_per_customer
  type: derived
  type_params:
    expr: "{{ metric('total_revenue') }} / {{ metric('customer_count') }}"
```

- "Chaque métrique est un objet de première classe. Vous pouvez découper `cancellation_rate` par région, par type de commande, par mois — et le dénominateur correspond toujours au numérateur. Aucun mauvais filtrage accidentel."
- "Et comme c'est du code, c'est versionné. Vous pouvez voir qui a modifié la définition de `total_revenue`, quand, et pourquoi."

> **Question d'audit répondue :** *Que signifie cette métrique ?*
> **Réponse :** Définitions explicites et versionnées. La logique métier vit dans le code, pas dans la tête de quelqu'un ou dans la config d'un outil BI.

---

## ACTE 6 : La Chaîne d'Audit Complète — "Tracer une réponse IA jusqu'à sa source"

C'est le moment de conclusion. Dessiner la chaîne de bout en bout :

```
Question IA :
"Quel est le chiffre d'affaires total par région ce mois-ci ?"
          |
          v
Métrique : total_revenue
  → défini comme sum(order_amount) dans semantic_models.yml
          |
          v
Modèle : fct_orders
  → union des commandes B2B et B2C
  → testé : not_null, unique, accepted_values sur le statut
          |
          v
Staging : stg_ret_orders
  → cast(amount as numeric(18,2))
  → filtre les lignes _fivetran_deleted
  → testé au niveau de la source
          |
          v
Source : HICHAMB_FIVETRAN_DEMO.retail.ret_orders
  → fraîcheur surveillée : avertissement 7h, erreur 13h
  → _fivetran_synced : 2026-04-06 16:41
          |
          v
Synchronisation Fivetran
  → Source : Google Cloud PostgreSQL
  → Dernière sync : 6 avr. 16h41, 1m 15s, Réussie
  → Journal de sync : historique auditable dans le tableau de bord Fivetran
```

**Phrase de conclusion :**

> "Quand quelqu'un demande *'peut-on faire confiance à cette réponse IA ?'* — avec cette stack, la réponse est oui. Vous pouvez tracer chaque chiffre depuis la réponse de l'IA jusqu'à la ligne exacte dans votre base de données source, la synchronisation Fivetran exacte qui l'a amenée, et chaque contrôle qualité qu'elle a passé en chemin.
>
> **Ce n'est pas juste de l'IA. C'est de l'IA auditable. C'est la différence.**"

---

## Aide-Mémoire des Commandes

```bash
# Configuration
cd ~/retail-fivetran-demo
export SNOWFLAKE_ACCOUNT=cmvgrnf.zna84829
export SNOWFLAKE_USER=HB
export SNOWFLAKE_PASSWORD=<votre_mot_de_passe>
export SNOWFLAKE_WAREHOUSE=COMPUTE_WH

# Installer les packages
~/.local/bin/dbt deps

# ACTE 2 : Vérification de la fraîcheur
~/.local/bin/dbt source freshness

# ACTE 3 : Tests qualité (staging uniquement, rapide)
~/.local/bin/dbt test --select staging

# Pipeline complet
~/.local/bin/dbt build

# ACTE 4 : Documentation et lignage
~/.local/bin/dbt docs generate
~/.local/bin/dbt docs serve
# → ouvrir http://localhost:8080
```

---

## Gestion des Objections

| Snowflake dit | Votre réponse |
|---------------|---------------|
| "Cortex peut interroger vos données directement" | "Interroger quoi, exactement ? Des tables brutes sans tests, sans garantie de fraîcheur, et des noms de colonnes comme `ret_orders.amount` ? Nous définissons ce que *chiffre d'affaires* signifie avant que l'IA n'y touche." |
| "Nous avons des fonctionnalités de qualité des données Snowflake" | "Très bien — et dbt orchestre ces contrôles dans votre pipeline, avec lignage, contrôle de version, et la capacité de bloquer le build si les tests échouent. Ce n'est pas l'un ou l'autre." |
| "Notre couche sémantique gère les définitions" | "Montrez-moi l'historique des versions de vos définitions de métriques. Avec dbt, chaque changement est un commit git — qui l'a modifié, quand, et pourquoi." |
| "C'est trop complexe" | "Vos données sont complexes. La question est de savoir si cette complexité est cachée ou visible. Nous la rendons visible." |

---

## Fichiers à Avoir Ouverts Pendant la Démo

1. **Onglet Fivetran** — statut de connexion + vue schéma (vos captures d'écran)
2. **Onglet Snowflake** — tables `HICHAMB_FIVETRAN_DEMO.retail`
3. **Terminal** — pour les commandes dbt
4. **VS Code / éditeur** avec ces fichiers ouverts :
   - `models/staging/fivetran_retail/_sources.yml` — fraîcheur + tests source
   - `models/staging/fivetran_retail/stg_ret_orders.sql` — montrer le filtre `_fivetran_deleted` + `cast()`
   - `models/marts/semantic_models.yml` — les définitions de métriques
   - `models/marts/metrics.yml` — montrer `cancellation_rate` ratio + `revenue_per_customer` dérivé
5. **Onglet dbt docs** (après `dbt docs serve`) — graphe de lignage
