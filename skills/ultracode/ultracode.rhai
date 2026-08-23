let meta = #{
    name: "ultracode",
    description: "Specialist review, claim verification, adjudication",
    phases: [
        #{ title: "Review", detail: "inspect, calibrate, and consolidate claims" },
        #{ title: "Verify", detail: "one independent verifier per distinct claim" },
        #{ title: "Adjudicate", detail: "account for every verified claim" },
    ],
};

let source_schema = #{
    "type": "object", "required": ["ref", "location"],
    "properties": #{
        "ref": #{ "type": "string", "minLength": 1 },
        "location": #{ "type": "string", "minLength": 1 },
    },
};
let discovered_source_schema = #{
    "type": "object", "required": ["ref", "kind", "locator", "sourceType", "reason", "inspected"],
    "properties": #{
        "ref": #{ "type": "string", "minLength": 1 },
        "kind": #{ "type": "string", "minLength": 1 },
        "locator": #{ "type": "string", "minLength": 1 },
        "sourceType": #{ "type": "string", "enum": ["primary", "secondary", "other"] },
        "reason": #{ "type": "string", "minLength": 1 },
        "inspected": #{ "type": "boolean" },
    },
};
let finding_schema = #{
    "type": "object", "required": [
        "title", "claim", "evidence", "impact", "materialityLevel", "materiality",
        "severity", "confidence", "lensFit", "sources"
    ],
    "properties": #{
        "title": #{ "type": "string", "minLength": 1, "maxLength": 80 },
        "claim": #{ "type": "string", "minLength": 1 },
        "evidence": #{ "type": "string", "minLength": 1 },
        "impact": #{ "type": "string", "minLength": 1 },
        "materialityLevel": #{ "type": "string", "enum": ["objective-blocking", "material", "significant", "limited"] },
        "materiality": #{ "type": "string", "minLength": 1 },
        "severity": #{ "type": "string", "enum": ["critical", "high", "medium", "low"] },
        "confidence": #{ "type": "string", "enum": ["high", "medium", "low"] },
        "lensFit": #{ "type": "string", "minLength": 1 },
        "sources": #{ "type": "array", "minItems": 1, "items": source_schema },
    },
};
let quality_gate_schema = #{
    "type": "object", "required": ["accepted", "reason"],
    "properties": #{
        "accepted": #{ "type": "boolean" },
        "reason": #{ "type": "string", "minLength": 1 },
    },
};
let findings_schema = #{
    "type": "object", "required": ["inspection", "discoveredSources", "findings"],
    "properties": #{
        "inspection": #{ "type": "string", "minLength": 1 },
        "discoveredSources": #{ "type": "array", "maxItems": 8, "items": discovered_source_schema },
        "findings": #{ "type": "array", "items": finding_schema },
    },
};
let dedupe_group_schema = #{
    "type": "object", "required": ["memberIds"],
    "properties": #{
        "memberIds": #{ "type": "array", "minItems": 1, "items": #{ "type": "string", "minLength": 1 } },
    },
};
let dedupe_schema = #{
    "type": "object", "required": ["groups"],
    "properties": #{
        "groups": #{ "type": "array", "minItems": 1, "items": dedupe_group_schema },
    },
};
let verdict_schema = #{
    "type": "object", "required": ["real", "reason", "evidence", "uncertainty", "discoveredSources"],
    "properties": #{
        "real": #{ "type": "boolean" },
        "reason": #{ "type": "string", "minLength": 1 },
        "evidence": #{ "type": "array", "minItems": 1, "items": source_schema },
        "uncertainty": #{ "type": "string" },
        "discoveredSources": #{ "type": "array", "maxItems": 8, "items": discovered_source_schema },
    },
};
let judgment_item_schema = #{
    "type": "object", "required": ["id", "why"],
    "properties": #{
        "id": #{ "type": "string", "minLength": 1 },
        "why": #{ "type": "string", "minLength": 1 },
    },
};
let judgment_schema = #{
    "type": "object", "required": ["kept", "dropped"],
    "properties": #{
        "kept": #{ "type": "array", "items": judgment_item_schema },
        "dropped": #{ "type": "array", "items": judgment_item_schema },
    },
};

fn trimmed(value) {
    if type_of(value) != "string" {
        ""
    } else {
        let out = value;
        out.trim();
        out
    }
}
fn has_unsafe_component(path) {
    if type_of(path) != "string" {
        true
    } else {
        let unsafe = false;
        for component in path.split("/") {
            if component == "." || component == ".." { unsafe = true; }
        }
        unsafe
    }
}
fn id_char_allowed(ch) {
    let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-";
    let ok = false;
    for candidate in allowed {
        if candidate == ch { ok = true; }
    }
    ok
}
fn id_valid(value) {
    if type_of(value) != "string" || value.len() == 0 || value.len() > 24 {
        false
    } else {
        let ok = true;
        for ch in value {
            if !id_char_allowed(ch) { ok = false; }
        }
        ok
    }
}
fn label_slug(value) {
    let out = "";
    if type_of(value) == "string" {
        for ch in value {
            if out.len() < 40 {
                let text = ch.to_string();
                if id_char_allowed(ch) {
                    out += text;
                } else if text == " " {
                    if out != "" && out.sub_string(out.len() - 1, 1) != " " {
                        out += " ";
                    }
                } else if out != "" && out.sub_string(out.len() - 1, 1) != " " && out.sub_string(out.len() - 1, 1) != "-" {
                    out += "-";
                }
            }
        }
    }
    if out != "" {
        let last = out.sub_string(out.len() - 1, 1);
        if last == " " || last == "-" {
            out = out.sub_string(0, out.len() - 1);
        }
    }
    if out == "" { "claim" } else { out }
}
fn string_in(list, value) {
    let found = false;
    if type_of(list) == "array" {
        for item in list {
            if item == value { found = true; }
        }
    }
    found
}
fn next_label(used, base) {
    let label = base;
    let n = 2;
    while string_in(used, label) {
        label = base + " " + n.to_string();
        n += 1;
    }
    label
}
fn named_label(used, role, name) {
    next_label(used, role + ": " + label_slug(name))
}
fn add_unique(list, value) {
    if !string_in(list, value) { list.push(value); }
    list
}
fn registry_source(registry, ref) {
    let found = ();
    for source in registry {
        if source.ref == ref { found = source; }
    }
    found
}
fn source_ref_allowed(ref, allowed_refs, registry, blocked_refs) {
    !string_in(blocked_refs, ref) && string_in(allowed_refs, ref) && registry_source(registry, ref) != ()
}
fn sources_allowed(sources, allowed_refs, registry, blocked_refs) {
    if type_of(sources) != "array" || sources.len() == 0 {
        false
    } else {
        let ok = true;
        for source in sources {
            if type_of(source) != "map" {
                ok = false;
            } else if trimmed(source.ref) == "" || trimmed(source.location) == "" {
                ok = false;
            } else if !source_ref_allowed(source.ref, allowed_refs, registry, blocked_refs) {
                ok = false;
            }
        }
        ok
    }
}
fn discovered_source_valid(source, artifact_kind) {
    if artifact_kind != "research" || type_of(source) != "map" {
        false
    } else if !id_valid(source.ref) || trimmed(source.kind) == "" || trimmed(source.locator) == "" {
        false
    } else if trimmed(source.reason) == "" || source.inspected != true {
        false
    } else {
        string_in(["primary", "secondary", "other"], source.sourceType)
    }
}
fn registration_status(registry, source, artifact_kind) {
    if !discovered_source_valid(source, artifact_kind) {
        "invalid"
    } else {
        let existing = registry_source(registry, source.ref);
        if existing == () {
            "new"
        } else if existing.provenance == "discovered" && existing.kind == source.kind && existing.locator == source.locator {
            "identical"
        } else {
            "conflict"
        }
    }
}
fn register_discovered(registry, source) {
    registry.push(#{
        ref: source.ref,
        kind: source.kind,
        locator: source.locator,
        role: "evidence",
        sourceType: source.sourceType,
        reason: source.reason,
        inspected: source.inspected,
        provenance: "discovered",
    });
    registry
}
fn severity_valid(value) {
    string_in(["critical", "high", "medium", "low"], value)
}
fn confidence_valid(value) {
    string_in(["high", "medium", "low"], value)
}
fn materiality_valid(value) {
    string_in(["objective-blocking", "material", "significant", "limited"], value)
}
fn severity_rank(value) {
    if value == "critical" { 4 }
    else if value == "high" { 3 }
    else if value == "medium" { 2 }
    else { 1 }
}
fn meets_threshold(severity, minimum) {
    severity_rank(severity) >= severity_rank(minimum)
}
fn finding_valid(finding, allowed_refs, registry, blocked_refs, minimum_severity) {
    if type_of(finding) != "map" {
        false
    } else if trimmed(finding.title) == "" || trimmed(finding.claim) == "" {
        false
    } else if trimmed(finding.evidence) == "" || trimmed(finding.impact) == "" {
        false
    } else if !materiality_valid(finding.materialityLevel) || trimmed(finding.materiality) == "" || trimmed(finding.lensFit) == "" {
        false
    } else if !severity_valid(finding.severity) || !confidence_valid(finding.confidence) {
        false
    } else if !meets_threshold(finding.severity, minimum_severity) {
        false
    } else {
        sources_allowed(finding.sources, allowed_refs, registry, blocked_refs)
    }
}
fn verdict_valid(verdict, allowed_refs, registry, blocked_refs) {
    if type_of(verdict) != "map" {
        false
    } else if type_of(verdict.real) != "bool" || trimmed(verdict.reason) == "" {
        false
    } else {
        sources_allowed(verdict.evidence, allowed_refs, registry, blocked_refs)
    }
}
fn slot_failed(result) {
    if result == () { true }
    else if result.success != true { true }
    else { result.output == () }
}
fn id_hits(list, id) {
    let count = 0;
    if type_of(list) == "array" {
        for item in list {
            if type_of(item) == "map" && item.id == id { count += 1; }
        }
    }
    count
}
fn finding_id_hits(findings, id) {
    let count = 0;
    for finding in findings {
        if finding.id == id { count += 1; }
    }
    count
}
fn groups_valid(groups, findings) {
    if type_of(groups) != "array" || groups.len() == 0 {
        false
    } else {
        let ok = true;
        for group in groups {
            if type_of(group) != "map" || type_of(group.memberIds) != "array" || group.memberIds.len() == 0 {
                ok = false;
            } else {
                for id in group.memberIds {
                    if finding_id_hits(findings, id) != 1 { ok = false; }
                }
            }
        }
        for finding in findings {
            let hits = 0;
            for group in groups {
                if type_of(group) == "map" && type_of(group.memberIds) == "array" {
                    for id in group.memberIds {
                        if id == finding.id { hits += 1; }
                    }
                }
            }
            if hits != 1 { ok = false; }
        }
        ok
    }
}
fn list_has_unknown_or_invalid(list, cases) {
    if type_of(list) != "array" {
        true
    } else {
        let bad = false;
        for item in list {
            if type_of(item) != "map" || trimmed(item.id) == "" || trimmed(item.why) == "" {
                bad = true;
            } else {
                let known = false;
                for c in cases {
                    if c.id == item.id { known = true; }
                }
                if !known { bad = true; }
            }
        }
        bad
    }
}
fn case_result(c, why) {
    #{
        id: c.id,
        title: c.title,
        claim: c.claim,
        members: c.members,
        allowedRefs: c.allowedRefs,
        verifierReal: c.verifierReal,
        verifierReason: c.verifierReason,
        verifierEvidence: c.verifierEvidence,
        verifierUncertainty: c.verifierUncertainty,
        verifierDiscoveredSources: c.verifierDiscoveredSources,
        why: why,
    }
}
fn summarize(kept, dropped, unjudged, no_verdict, quality_rejected, failed_reviewers, judge_errors) {
    kept.len().to_string() + " kept, "
        + dropped.len().to_string() + " dropped, "
        + unjudged.len().to_string() + " unjudged, "
        + no_verdict.len().to_string() + " noVerdict, "
        + quality_rejected.len().to_string() + " qualityRejected, "
        + failed_reviewers.len().to_string() + " failedReviewers, "
        + judge_errors.len().to_string() + " judgeErrors"
}
fn with_model(job, model) {
    if trimmed(model) != "" {
        job.model = model;
    }
    job
}

let brief = ();
let dimensions = ();
let agent_model = "";
let agent_effort = "";
if type_of(args) == "map" {
    if type_of(args.brief) == "map" { brief = args.brief; }
    if type_of(args.dimensions) == "array" { dimensions = args.dimensions; }
    if type_of(args.model) == "string" { agent_model = trimmed(args.model); }
    if type_of(args.effort) == "string" { agent_effort = trimmed(args.effort); }
}
let effort_instruction = "";
if agent_effort != "" {
    effort_instruction = " Use reasoning effort " + agent_effort + " for this task.";
}
if type_of(brief) != "map" {
    pause("verification", "Pass args.brief as a structured review brief. Start a new run with corrected args.");
}
let objective = brief.objective;
let target = brief.target;
let artifact_kind = brief.artifact_kind;
let inspection = brief.inspection;
let artifacts = brief.artifacts;
let minimum_severity = brief.minimum_severity;
let max_findings_per_reviewer = if brief.max_findings_per_reviewer == () { 11 } else { brief.max_findings_per_reviewer };
let dedupe_threshold = brief.dedupe_threshold;
if trimmed(objective) == "" || trimmed(target) == "" || trimmed(inspection) == "" {
    pause("verification", "brief needs nonempty objective, target, and inspection strings. Start a new run.");
}
if !string_in(["file", "directory", "diff", "text", "mixed", "research"], artifact_kind) {
    pause("verification", "brief.artifact_kind is invalid. Start a new run.");
}
if !severity_valid(minimum_severity) {
    pause("verification", "brief.minimum_severity must be critical, high, medium, or low. Start a new run.");
}
if type_of(max_findings_per_reviewer) != "i64" || max_findings_per_reviewer < 1 {
    pause("verification", "brief.max_findings_per_reviewer must be a positive integer. Start a new run.");
}
if type_of(dedupe_threshold) != "i64" || dedupe_threshold < 2 {
    pause("verification", "brief.dedupe_threshold must be an integer of at least 2. Start a new run.");
}
if type_of(artifacts) != "array" || artifacts.len() == 0 {
    pause("verification", "brief.artifacts must contain at least one artifact manifest entry. Start a new run.");
}
let artifact_refs = [];
for artifact in artifacts {
    if type_of(artifact) != "map" || !id_valid(artifact.ref) {
        pause("verification", "Each artifact needs a unique safe ref of at most 24 letters, numbers, or hyphens. Start a new run.");
    } else if string_in(artifact_refs, artifact.ref) {
        pause("verification", "Artifact refs must be unique. Start a new run.");
    } else if trimmed(artifact.kind) == "" || trimmed(artifact.locator) == "" || trimmed(artifact.role) == "" {
        pause("verification", "Each artifact needs nonempty kind, locator, and role strings. Start a new run.");
    }
    if string_in(["file", "directory", "diff"], artifact.kind) && has_unsafe_component(artifact.locator) {
        pause("verification", "Local artifact locators cannot contain . or .. path components. Start a new run.");
    }
    artifact_refs.push(artifact.ref);
}
if type_of(dimensions) != "array" || dimensions.len() < 3 || dimensions.len() > 5 {
    pause("verification", "Pass 3-5 dimensions. Start a new run with corrected args.");
}
let dimension_ids = [];
for dimension in dimensions {
    if type_of(dimension) != "map" || !id_valid(dimension.id) || string_in(dimension_ids, dimension.id) {
        pause("verification", "Each dimension needs a unique safe id. Start a new run.");
    } else if trimmed(dimension.name) == "" || trimmed(dimension.justification) == "" || trimmed(dimension.focus) == "" {
        pause("verification", "Each dimension needs nonempty name, justification, and focus strings. Start a new run.");
    } else if type_of(dimension.excludes) != "array" || dimension.excludes.len() == 0 {
        pause("verification", "Each dimension needs at least one explicit exclusion. Start a new run.");
    } else if type_of(dimension.scope_refs) != "array" || dimension.scope_refs.len() == 0 {
        pause("verification", "Each dimension needs at least one scope ref. Start a new run.");
    } else if dimension.reviewer_count != 1 && dimension.reviewer_count != 2 {
        pause("verification", "dimension.reviewer_count must be 1 or 2. Start a new run.");
    } else if dimension.reviewer_count == 2 && trimmed(dimension.redundancy_reason) == "" {
        pause("verification", "A duplicated reviewer needs a nonempty redundancy_reason. Start a new run.");
    }
    for exclusion in dimension.excludes {
        if trimmed(exclusion) == "" { pause("verification", "Dimension exclusions cannot be empty. Start a new run."); }
    }
    for ref in dimension.scope_refs {
        if !string_in(artifact_refs, ref) { pause("verification", "Every dimension scope ref must exist in brief.artifacts. Start a new run."); }
    }
    dimension_ids.push(dimension.id);
}

let registry = [];
for artifact in artifacts {
    registry.push(#{
        ref: artifact.ref,
        kind: artifact.kind,
        locator: artifact.locator,
        role: artifact.role,
        sourceType: "supplied",
        reason: "supplied in review brief",
        inspected: false,
        provenance: "supplied",
    });
}
let brief_js = json_encode(brief);
let artifacts_js = json_encode(artifacts);

phase("Review");
let used_labels = [];
let review_jobs = [];
for dimension in dimensions {
    let reviewer_index = 1;
    while reviewer_index <= dimension.reviewer_count {
        let dimension_js = json_encode(dimension);
        let prompt = "Review the structured brief under exactly one lens. Brief JSON: ";
        prompt += brief_js;
        prompt += ". Artifact manifest JSON: ";
        prompt += artifacts_js;
        prompt += ". Dimension JSON: ";
        prompt += dimension_js;
        prompt += ". Reviewer ordinal: ";
        prompt += reviewer_index.to_string();
        prompt += ". Follow the dimension focus and exclusions. Inspect only its scope_refs under the brief inspection contract. ";
        prompt += "For research, register each new source in discoveredSources before citing it; prefer primary sources. Other artifact kinds must return discoveredSources as an empty array. ";
        prompt += "Return a concrete inspection account and at most ";
        prompt += max_findings_per_reviewer.to_string();
        prompt += " material findings. Each finding needs title, precise claim, inspected evidence, impact, materialityLevel, materiality explanation, severity, confidence, lensFit, and auditable {ref, location} sources. ";
        prompt += "Materiality: objective-blocking prevents the objective; material materially changes the decision or outcome; significant needs action but does not decide the objective alone; limited has contained effect. ";
        prompt += "Severity: critical defeats the objective or creates unacceptable harm; high is a likely material failure; medium is important with a viable workaround; low has limited impact. ";
        prompt += "Confidence: high has direct specific evidence with no material contradiction; medium has specific evidence with a material uncertainty; low is plausible but weak or incomplete. ";
        prompt += "Do not report findings below the brief minimum_severity. An empty list is valid only with a concrete inspection account.";
        prompt += effort_instruction;
        let review_name = dimension.name;
        if dimension.reviewer_count > 1 {
            review_name = dimension.name + " R" + reviewer_index.to_string();
        }
        let review_label = named_label(used_labels, "review", review_name);
        used_labels.push(review_label);
        review_jobs.push(with_model(#{
            prompt: prompt,
            label: review_label,
            capability_mode: "read-only",
            output_schema: findings_schema,
        }, agent_model));
        reviewer_index += 1;
    }
}
let review_results = parallel(review_jobs);

let findings = [];
let pending_findings = [];
let inspections = [];
let coverage = [];
let quality_rejected = [];
let failed_reviewers = [];
let source_errors = [];
let result_index = 0;
for dimension in dimensions {
    let successful_reviewers = 0;
    let accepted_count = 0;
    let reviewer_index = 1;
    while reviewer_index <= dimension.reviewer_count {
        let result = if result_index < review_results.len() { review_results[result_index] } else { () };
        let reviewer_id = dimension.id + "-R" + reviewer_index.to_string();
        if slot_failed(result) {
            failed_reviewers.push(#{ dimensionId: dimension.id, reviewerId: reviewer_id, reason: "reviewer failed or returned no output" });
        } else if type_of(result.output) != "map" || trimmed(result.output.inspection) == "" || type_of(result.output.findings) != "array" || type_of(result.output.discoveredSources) != "array" {
            failed_reviewers.push(#{ dimensionId: dimension.id, reviewerId: reviewer_id, reason: "reviewer output was malformed" });
        } else {
            successful_reviewers += 1;
            let reviewer_discovered_refs = [];
            for discovered in result.output.discoveredSources {
                let status = registration_status(registry, discovered, artifact_kind);
                if status == "new" {
                    registry = register_discovered(registry, discovered);
                    reviewer_discovered_refs = add_unique(reviewer_discovered_refs, discovered.ref);
                } else if status == "identical" {
                    reviewer_discovered_refs = add_unique(reviewer_discovered_refs, discovered.ref);
                    source_errors.push(#{ reviewerId: reviewer_id, entry: discovered, reason: "reused an identical discovered source registration" });
                } else if status == "conflict" {
                    source_errors.push(#{ reviewerId: reviewer_id, entry: discovered, reason: "discovered source ref conflicts with the registered locator" });
                } else {
                    source_errors.push(#{ reviewerId: reviewer_id, entry: discovered, reason: "invalid or unauthorized discovered source" });
                }
            }
            inspections.push(#{
                dimensionId: dimension.id,
                reviewerId: reviewer_id,
                lens: dimension.name,
                scopeRefs: dimension.scope_refs,
                inspection: result.output.inspection,
                reportedCount: result.output.findings.len(),
            });
            let finding_index = 1;
            for finding in result.output.findings {
                let id = reviewer_id + "-F" + finding_index.to_string();
                let basic_finding_valid = type_of(finding) == "map"
                    && trimmed(finding.title) != "" && trimmed(finding.claim) != ""
                    && trimmed(finding.evidence) != "" && trimmed(finding.impact) != ""
                    && materiality_valid(finding.materialityLevel) && trimmed(finding.materiality) != ""
                    && severity_valid(finding.severity) && confidence_valid(finding.confidence)
                    && trimmed(finding.lensFit) != "" && meets_threshold(finding.severity, minimum_severity);
                if finding_index > max_findings_per_reviewer {
                    quality_rejected.push(#{
                        id: id,
                        dimensionId: dimension.id,
                        reviewerId: reviewer_id,
                        entry: finding,
                        reason: "finding exceeds brief.max_findings_per_reviewer",
                    });
                } else if basic_finding_valid {
                    pending_findings.push(#{
                        id: id,
                        dimensionId: dimension.id,
                        reviewerId: reviewer_id,
                        lens: dimension.name,
                        justification: dimension.justification,
                        focus: dimension.focus,
                        excludes: dimension.excludes,
                        scopeRefs: dimension.scope_refs,
                        reviewerDiscoveredRefs: reviewer_discovered_refs,
                        title: finding.title,
                        claim: finding.claim,
                        evidence: finding.evidence,
                        impact: finding.impact,
                        materialityLevel: finding.materialityLevel,
                        materiality: finding.materiality,
                        severity: finding.severity,
                        confidence: finding.confidence,
                        lensFit: finding.lensFit,
                        sources: finding.sources,
                        inspection: result.output.inspection,
                    });
                    accepted_count += 1;
                } else {
                    quality_rejected.push(#{
                        id: id,
                        dimensionId: dimension.id,
                        reviewerId: reviewer_id,
                        entry: finding,
                        reason: "finding failed shape, calibration, severity threshold, or source-registry checks",
                    });
                }
                finding_index += 1;
            }
        }
        reviewer_index += 1;
        result_index += 1;
    }
    let status = if successful_reviewers == dimension.reviewer_count { "complete" }
        else if successful_reviewers > 0 { "partial" }
        else { "failed" };
    coverage.push(#{
        dimensionId: dimension.id,
        lens: dimension.name,
        expectedReviewers: dimension.reviewer_count,
        successfulReviewers: successful_reviewers,
        acceptedFindings: accepted_count,
        status: status,
    });
}

for finding in pending_findings {
    let reviewer_allowed_refs = finding.scopeRefs;
    for ref in finding.reviewerDiscoveredRefs { reviewer_allowed_refs = add_unique(reviewer_allowed_refs, ref); }
    if finding_valid(finding, reviewer_allowed_refs, registry, [], minimum_severity) {
        findings.push(finding);
    } else {
        quality_rejected.push(#{ id: finding.id, dimensionId: finding.dimensionId, reviewerId: finding.reviewerId, entry: finding, reason: "finding failed final source-registry authorization after all Review registrations" });
    }
}

let quality_gate_jobs = [];
for finding in findings {
    let finding_js = json_encode(finding);
    let prompt = "Classify whether this finding passes the Review quality gate. Review objective: ";
    prompt += json_encode(objective);
    prompt += ". Use only the supplied JSON; do not inspect artifacts or judge whether the claim is true. ";
    prompt += "Accept only when the claim is inside focus and outside every exclusion; lensFit specifically establishes that relationship; severity matches impact; materialityLevel matches how the claim affects the objective; and confidence matches the specificity, completeness, and uncertainty of the stated evidence. ";
    prompt += "Return accepted and a concrete reason.";
    prompt += effort_instruction;
    prompt += " Finding JSON: ";
    prompt += finding_js;
    let gate_label = named_label(used_labels, "gate", finding.title);
    used_labels.push(gate_label);
    quality_gate_jobs.push(with_model(#{
        prompt: prompt,
        label: gate_label,
        capability_mode: "read-only",
        output_schema: quality_gate_schema,
    }, agent_model));
}
let quality_gate_results = parallel(quality_gate_jobs);
let gated_findings = [];
let gate_index = 0;
for finding in findings {
    let gate = if gate_index < quality_gate_results.len() { quality_gate_results[gate_index] } else { () };
    if slot_failed(gate) || type_of(gate.output) != "map" || type_of(gate.output.accepted) != "bool" || trimmed(gate.output.reason) == "" {
        quality_rejected.push(#{ id: finding.id, dimensionId: finding.dimensionId, reviewerId: finding.reviewerId, entry: finding, reason: "Review quality gate failed or returned malformed output" });
    } else if gate.output.accepted != true {
        quality_rejected.push(#{ id: finding.id, dimensionId: finding.dimensionId, reviewerId: finding.reviewerId, entry: finding, reason: gate.output.reason });
    } else {
        finding.qualityGateReason = gate.output.reason;
        gated_findings.push(finding);
    }
    gate_index += 1;
}
findings = gated_findings;
let updated_coverage = [];
for item in coverage {
    let accepted_count = 0;
    for finding in findings {
        if finding.dimensionId == item.dimensionId { accepted_count += 1; }
    }
    updated_coverage.push(#{
        dimensionId: item.dimensionId,
        lens: item.lens,
        expectedReviewers: item.expectedReviewers,
        successfulReviewers: item.successfulReviewers,
        acceptedFindings: accepted_count,
        status: item.status,
    });
}
coverage = updated_coverage;
if findings.len() == 0 {
    complete(#{
        summary: summarize([], [], [], [], quality_rejected, failed_reviewers, []),
        kept: [], dropped: [], unjudged: [], noVerdict: [],
        inspections: inspections, coverage: coverage, qualityRejected: quality_rejected,
        failedReviewers: failed_reviewers, sourceRegistry: registry, sourceErrors: source_errors,
        dedupe: #{ attempted: false, applied: false, groups: [], errors: [] }, judgeErrors: [],
    });
}

let verification_items = [];
let dedupe_errors = [];
let dedupe_groups = [];
let dedupe_attempted = findings.len() >= dedupe_threshold;
let dedupe_applied = false;
if dedupe_attempted {
    let findings_js = json_encode(findings);
    let prompt = "Consolidate semantically equivalent review findings before verification. Use only the supplied JSON; do not inspect artifacts and do not judge truth. ";
    prompt += "Group duplicates that make the same falsifiable claim despite different wording or lenses. Keep distinct claims separate. ";
    prompt += "Every finding id must appear exactly once across groups. Order each memberIds list by the findings' input order, and order groups by their earliest member. ";
    prompt += "Return member IDs only; do not rewrite titles or claims.";
    prompt += effort_instruction;
    prompt += " Findings JSON: ";
    prompt += findings_js;
    let dedupe_result = agent(prompt, with_model(#{
        label: "review:deduplicate",
        capability_mode: "read-only",
        output_schema: dedupe_schema,
    }, agent_model));
    if slot_failed(dedupe_result) || type_of(dedupe_result.output) != "map" || !groups_valid(dedupe_result.output.groups, findings) {
        dedupe_errors.push("deduplication failed or did not partition every finding exactly once");
    } else {
        dedupe_applied = true;
        dedupe_groups = dedupe_result.output.groups;
    }
}
if dedupe_applied {
    let ordered_groups = [];
    let added_ids = [];
    for finding in findings {
        for group in dedupe_groups {
            if string_in(group.memberIds, finding.id) && !string_in(added_ids, finding.id) {
                ordered_groups.push(group);
                for id in group.memberIds { added_ids.push(id); }
            }
        }
    }
    dedupe_groups = ordered_groups;
    for group in dedupe_groups {
        let members = [];
        let allowed_refs = [];
        for finding in findings {
            if string_in(group.memberIds, finding.id) {
                members.push(finding);
                for ref in finding.scopeRefs { allowed_refs = add_unique(allowed_refs, ref); }
                for ref in finding.reviewerDiscoveredRefs { allowed_refs = add_unique(allowed_refs, ref); }
            }
        }
        let primary = members[0];
        let id = primary.id + "-C";
        verification_items.push(#{ id: id, title: primary.title, claim: primary.claim, members: members, allowedRefs: allowed_refs });
    }
} else {
    for finding in findings {
        let allowed_refs = finding.scopeRefs;
        for ref in finding.reviewerDiscoveredRefs { allowed_refs = add_unique(allowed_refs, ref); }
        verification_items.push(#{ id: finding.id, title: finding.title, claim: finding.claim, members: [finding], allowedRefs: allowed_refs });
    }
}

phase("Verify");
let verify_jobs = [];
let registry_js = json_encode(registry);
for item in verification_items {
    let item_js = json_encode(item);
    let prompt = "Independently attempt to falsify one distinct review claim. Structured brief JSON: ";
    prompt += brief_js;
    prompt += ". Current source registry JSON: ";
    prompt += registry_js;
    prompt += ". Verification item JSON: ";
    prompt += item_js;
    prompt += ". Inspect independently under the brief inspection contract. Preserve every member's lens, exclusions, and scope. ";
    prompt += "For research, register new inspected sources in discoveredSources before citing them; other artifact kinds must return an empty discoveredSources array. ";
    prompt += "Set real=true only if the canonical claim survives falsification. Set real=false when evidence refutes it. ";
    prompt += "Evidence requires exact registered {ref, location} references and reason must explain how they prove or refute the claim. Put remaining uncertainty in uncertainty.";
    prompt += effort_instruction;
    let verify_label = named_label(used_labels, "verify", item.title);
    used_labels.push(verify_label);
    verify_jobs.push(with_model(#{
        prompt: prompt,
        label: verify_label,
        capability_mode: "read-only",
        output_schema: verdict_schema,
    }, agent_model));
}
let verdicts = parallel(verify_jobs);

let cases = [];
let no_verdict = [];
let verifier_source_failures = [];
let verifier_discovered_refs = [];
let item_index = 0;
for item in verification_items {
    let verdict = if item_index < verdicts.len() { verdicts[item_index] } else { () };
    if !slot_failed(verdict) && type_of(verdict.output) == "map" && type_of(verdict.output.discoveredSources) == "array" {
        let verifier_source_error = false;
        for discovered in verdict.output.discoveredSources {
            let status = registration_status(registry, discovered, artifact_kind);
            if status == "new" {
                registry = register_discovered(registry, discovered);
                verifier_discovered_refs.push(#{ verifierId: item.id, ref: discovered.ref });
            } else if status == "identical" {
                verifier_discovered_refs.push(#{ verifierId: item.id, ref: discovered.ref });
                source_errors.push(#{ verifierId: item.id, entry: discovered, reason: "reused an identical discovered source registration" });
            } else if status == "conflict" {
                verifier_source_error = true;
                source_errors.push(#{ verifierId: item.id, entry: discovered, reason: "discovered source ref conflicts with the registered locator" });
            } else {
                verifier_source_error = true;
                source_errors.push(#{ verifierId: item.id, entry: discovered, reason: "invalid or unauthorized verifier-discovered source" });
            }
        }
        if verifier_source_error { verifier_source_failures.push(item.id); }
    }
    item_index += 1;
}
item_index = 0;
for item in verification_items {
    let verdict = if item_index < verdicts.len() { verdicts[item_index] } else { () };
    if slot_failed(verdict) {
        no_verdict.push(#{ item: item, verifierOutput: (), reason: "verifier failed or returned no output" });
    } else if type_of(verdict.output) != "map" || type_of(verdict.output.discoveredSources) != "array" {
        no_verdict.push(#{ item: item, verifierOutput: verdict.output, reason: "verifier output was malformed" });
    } else {
        let verifier_allowed_refs = item.allowedRefs;
        if artifact_kind == "research" {
            for registered in verifier_discovered_refs {
                if registered.verifierId == item.id { verifier_allowed_refs = add_unique(verifier_allowed_refs, registered.ref); }
            }
        }
        if string_in(verifier_source_failures, item.id) || !verdict_valid(verdict.output, verifier_allowed_refs, registry, []) {
            no_verdict.push(#{ item: item, verifierOutput: verdict.output, reason: "invalid, conflicted, or out-of-scope verifier evidence" });
        } else {
            cases.push(#{
                id: item.id,
                title: item.title,
                claim: item.claim,
                members: item.members,
                allowedRefs: verifier_allowed_refs,
                verifierReal: verdict.output.real,
                verifierReason: verdict.output.reason,
                verifierEvidence: verdict.output.evidence,
                verifierUncertainty: verdict.output.uncertainty,
                verifierDiscoveredSources: verdict.output.discoveredSources,
            });
        }
    }
    item_index += 1;
}
if cases.len() == 0 {
    complete(#{
        summary: summarize([], [], [], no_verdict, quality_rejected, failed_reviewers, []),
        kept: [], dropped: [], unjudged: [], noVerdict: no_verdict,
        inspections: inspections, coverage: coverage, qualityRejected: quality_rejected,
        failedReviewers: failed_reviewers, sourceRegistry: registry, sourceErrors: source_errors,
        dedupe: #{ attempted: dedupe_attempted, applied: dedupe_applied, groups: dedupe_groups, errors: dedupe_errors }, judgeErrors: [],
    });
}

phase("Adjudicate");
let cases_js = json_encode(cases);
let judge_prompt = "Adjudicate only the supplied Review+Verify cases. Objective: ";
judge_prompt += json_encode(objective);
judge_prompt += ". Do not inspect artifacts, discover sources, or invent findings. ";
judge_prompt += "Use each member's lens contract, severity, materiality, evidence, and the verifier record. ";
judge_prompt += "Keep a claim only when it is material to the objective and survives verification. Drop refuted, unsupported, duplicate, or immaterial claims. ";
judge_prompt += "If verifierReal=false, drop it. Every case id must appear exactly once in kept or dropped with a concrete nonempty why.";
judge_prompt += effort_instruction;
judge_prompt += " Cases JSON: ";
judge_prompt += cases_js;
let judgment = agent(judge_prompt, with_model(#{
    label: "adjudicate",
    capability_mode: "read-only",
    output_schema: judgment_schema,
}, agent_model));

let kept = [];
let dropped = [];
let unjudged = [];
let judge_errors = [];
if slot_failed(judgment) || type_of(judgment.output) != "map" {
    judge_errors.push("judge failed or returned no structured output");
} else if type_of(judgment.output.kept) != "array" || type_of(judgment.output.dropped) != "array" {
    judge_errors.push("judge kept/dropped lists are malformed");
} else if list_has_unknown_or_invalid(judgment.output.kept, cases) || list_has_unknown_or_invalid(judgment.output.dropped, cases) {
    judge_errors.push("judge returned an unknown id or an empty/invalid rationale");
}
if judge_errors.len() > 0 {
    for c in cases { unjudged.push(case_result(c, "invalid judge output")); }
} else {
    let kept_list = judgment.output.kept;
    let dropped_list = judgment.output.dropped;
    for c in cases {
        let kept_count = id_hits(kept_list, c.id);
        let dropped_count = id_hits(dropped_list, c.id);
        if c.verifierReal == false && kept_count == 1 && dropped_count == 0 {
            dropped.push(case_result(c, "verifier refuted the claim with evidence"));
        } else if kept_count == 1 && dropped_count == 0 {
            let why = "";
            for item in kept_list { if item.id == c.id { why = item.why; } }
            kept.push(case_result(c, why));
        } else if dropped_count == 1 && kept_count == 0 {
            let why = "";
            for item in dropped_list { if item.id == c.id { why = item.why; } }
            dropped.push(case_result(c, why));
        } else {
            unjudged.push(case_result(c, "judge omitted the id, duplicated it, or put it in both lists"));
        }
    }
}

complete(#{
    summary: summarize(kept, dropped, unjudged, no_verdict, quality_rejected, failed_reviewers, judge_errors),
    kept: kept, dropped: dropped, unjudged: unjudged, noVerdict: no_verdict,
    inspections: inspections, coverage: coverage, qualityRejected: quality_rejected,
    failedReviewers: failed_reviewers, sourceRegistry: registry, sourceErrors: source_errors,
    dedupe: #{ attempted: dedupe_attempted, applied: dedupe_applied, groups: dedupe_groups, errors: dedupe_errors },
    judgeErrors: judge_errors,
});
