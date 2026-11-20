<!-- Rule-type changes (a business rule, validation or blocking check added or
     altered, or an execution path introduced/reordered): one Scenario per
     rule-boundary conclusion, covering three kinds - blocked (with the minimal
     blocking condition), allowed (exceptions and legitimate counter-examples),
     and allowed on equivalent execution paths (one Scenario per path).
     Conclusions that do not apply are stated with a reason. Blocked-side
     scenarios alone count as an incomplete spec.

     Fourth mandatory kind - cross-interface business chains (跨接口业务链路):
     when the change touches a chain spanning more than one interface, write it
     as one testable chain. WHEN states the order of operations; THEN states the
     field contents the later query returns, field by field (defaults, derived
     values, status markers included). One scenario per endpoint hides the
     ordering effect and does not satisfy this. -->

## ADDED Requirements

### Requirement: <!-- requirement name -->
<!-- requirement text -->

#### Scenario: <!-- scenario name -->
- **WHEN** <!-- condition -->
- **THEN** <!-- expected outcome -->
