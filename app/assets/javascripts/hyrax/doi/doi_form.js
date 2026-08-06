// Behavior for the DOI tab on the deposit form and the mint button on a work's show page.
// Event-delegated handlers on document so they work whether or not the tab is the visible
// pane at load. A sentinel guards against the IIFE running twice (Turbolinks evaluates
// scripts again on some navigation paths in development), which would otherwise stack
// duplicate listeners and mint a DOI once per stacked handler.
(function() {
    if (document.hyraxDoiFormBound) return;
    document.hyraxDoiFormBound = true;

    function csrfToken() {
        var meta = document.querySelector('meta[name="csrf-token"]');
        return meta ? meta.getAttribute('content') : '';
    }

    function setStatus(container, message, isError, selector) {
        var status = container.querySelector(selector || '[data-doi-status]');
        if (!status) return;
        status.textContent = message || '';
        status.classList.toggle('text-danger', !!isError);
    }

    // Hydra-editor renders every field as a <ul class="listing"> of inputs sharing a
    // `.{param_key}_{field}` wrapper class. Only the first input is filled: adding rows
    // would mean driving Hyrax's own add-row handler, and the depositor can add more.
    function fillField(paramKey, field, values) {
        var wrapper = document.querySelector('.' + paramKey + '_' + field);
        if (!wrapper) return false;
        var input = wrapper.querySelector('input.multi-text-field, textarea.multi-text-field');
        if (!input) return false;
        var value = Array.isArray(values) ? values[0] : values;
        if (value === undefined || value === null || value === '') return false;
        input.value = value;
        // Hyrax and any autocomplete bound to the field listen for change, not assignment.
        input.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
    }

    // Both buttons POST to reserve an identifier and differ only in what they do with the
    // DOI that comes back: the deposit form puts it in the input, the show page displays
    // it. Neither re-enables on success -- a second click would reserve a second DOI.
    document.addEventListener('click', function(event) {
        var button = event.target.closest('[data-doi-draft-button], [data-doi-mint-button]');
        if (!button) return;
        event.preventDefault();

        var container = button.closest('[data-doi-tab], [data-doi-mint]');
        if (!container) return;
        var input = container.querySelector('[data-doi-input]');

        button.disabled = true;
        setStatus(container, button.getAttribute('data-doi-working'), false);

        fetch(button.getAttribute('data-doi-url'), {
            method: 'POST',
            credentials: 'same-origin',
            headers: {
                'X-CSRF-Token': csrfToken(),
                'Accept': 'application/json'
            }
        }).then(function(response) {
            return response.json().then(function(body) {
                return { ok: response.ok, body: body };
            });
        }).then(function(result) {
            if (!result.ok) {
                button.disabled = false;
                setStatus(container, result.body.error, true);
                return;
            }
            if (input) {
                input.value = result.body.doi;
                setStatus(container, '', false);
            } else {
                setStatus(container, result.body.doi, false);
            }
        }).catch(function() {
            button.disabled = false;
            setStatus(container, button.getAttribute('data-doi-error'), true);
        });
    });

    // Fills the form from an existing DOI's published metadata. This overwrites whatever
    // the depositor has typed, so it confirms first.
    document.addEventListener('click', function(event) {
        var button = event.target.closest('[data-doi-autofill-button]');
        if (!button) return;
        event.preventDefault();

        var container = button.closest('[data-doi-tab]');
        if (!container) return;
        var STATUS = '[data-doi-autofill-status]';

        var input = container.querySelector('[data-doi-input]');
        var doi = input ? input.value.trim() : '';
        if (!doi) {
            setStatus(container, button.getAttribute('data-doi-missing'), true, STATUS);
            return;
        }
        if (!window.confirm(button.getAttribute('data-doi-confirm'))) return;

        var paramKey = button.getAttribute('data-doi-param-key');
        button.disabled = true;
        setStatus(container, button.getAttribute('data-doi-working'), false, STATUS);

        var url = button.getAttribute('data-doi-url') + '?doi=' + encodeURIComponent(doi);
        fetch(url, {
            credentials: 'same-origin',
            headers: { 'Accept': 'application/json' }
        }).then(function(response) {
            return response.json().then(function(body) {
                return { ok: response.ok, body: body };
            });
        }).then(function(result) {
            button.disabled = false;
            if (!result.ok) {
                setStatus(container, result.body.error, true, STATUS);
                return;
            }
            var attributes = result.body.attributes || {};
            var filled = Object.keys(attributes).filter(function(field) {
                return fillField(paramKey, field, attributes[field]);
            });
            // A DOI can resolve to metadata whose fields this work type does not have, so
            // say so rather than leaving the form apparently unchanged for no reason.
            if (filled.length) {
                setStatus(container, '', false, STATUS);
            } else {
                setStatus(container, button.getAttribute('data-doi-empty'), true, STATUS);
            }
        }).catch(function() {
            button.disabled = false;
            setStatus(container, button.getAttribute('data-doi-error'), true, STATUS);
        });
    });

    // Warn before saving a work whose DOI is meant to reach a state DataCite validates
    // while fields it requires are blank. Drafts need no metadata, so they are exempt.
    document.addEventListener('click', function(event) {
        var submit = event.target.closest('#with_files_submit');
        if (!submit) return;

        var container = document.querySelector('[data-doi-tab]');
        if (!container) return;

        var checked = container.querySelector('[data-doi-status-radio]:checked');
        if (!checked || ['registered', 'findable'].indexOf(checked.value) < 0) return;

        var fields;
        try {
            fields = JSON.parse(container.getAttribute('data-doi-required-fields') || '[]');
        } catch (e) {
            return;
        }

        var missing = fields.filter(function(field) {
            var input = document.querySelector(field.selector + ' .form-control');
            // A field absent from the DOM is not a field the depositor left blank.
            return input && input.value.trim() === '';
        }).map(function(field) {
            return field.label;
        });
        if (missing.length === 0) return;

        var template = container.getAttribute('data-doi-missing-warning') || '';
        if (!window.confirm(template.replace('%{fields}', missing.join(', ')))) {
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    });
})();
