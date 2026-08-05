// Behavior for the DOI tab on the deposit form (see app/views/hyrax/base/_form_doi.html.erb).
// Event-delegated handlers on document so the tab works whether or not it is the visible
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

    function setStatus(container, message, isError) {
        var status = container.querySelector('[data-doi-status]');
        if (!status) return;
        status.textContent = message || '';
        status.classList.toggle('text-danger', !!isError);
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
