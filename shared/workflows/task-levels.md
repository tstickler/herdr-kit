# Task levels

Pick by risk first and size second. Assign the lowest level that can handle the task safely.

| Level | Use for |
|---|---|
| `low` | One fully specified change with exact files, an exact edit, and an exact check. |
| `medium` | A straightforward change across several files. |
| `high` | Larger changes in one or two modules, changes inside sensitive code that preserve its contract, or unknowns that need investigation. |
| `deep` | Abstract work across modules or a change to the behavior or outputs of a sensitive flow. |

Sensitive areas include money and purchases, auth and account merges, migrations that change data,
public or shipped API contracts, and anything that can lose user data. Project notes may add to this list.
