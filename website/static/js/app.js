document.addEventListener('DOMContentLoaded', function() {
    // --- 1. UNIVERSAL THEME LOGIC ---
    const lightThemeBtn = document.getElementById('theme-btn-light');
    const darkThemeBtn = document.getElementById('theme-btn-dark');

    function applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        if (lightThemeBtn && darkThemeBtn) {
            if (theme === 'dark') {
                darkThemeBtn.classList.add('active-theme');
                lightThemeBtn.classList.remove('active-theme');
            } else {
                lightThemeBtn.classList.add('active-theme');
                darkThemeBtn.classList.remove('active-theme');
            }
        }
    }

    if (lightThemeBtn && darkThemeBtn) {
        lightThemeBtn.addEventListener('click', () => {
            localStorage.setItem('theme', 'light');
            applyTheme('light');
        });
        darkThemeBtn.addEventListener('click', () => {
            localStorage.setItem('theme', 'dark');
            applyTheme('dark');
        });
    }
    const savedTheme = localStorage.getItem('theme') || 'dark';
    applyTheme(savedTheme);

    // --- 2. FORM-SPECIFIC LOGIC ---
    const form = document.getElementById('profile-form');
    if (!form) return;

    // --- COLLAPSE/EXPAND LOGIC ---
    function setCardCollapseState(cardElement, shouldBeCollapsed) {
        const toggleButtonText = cardElement.querySelector('.toggle-text');
        if (shouldBeCollapsed) {
            cardElement.classList.add('is-collapsed');
            if (toggleButtonText) toggleButtonText.textContent = 'Expand';
        } else {
            cardElement.classList.remove('is-collapsed');
            if (toggleButtonText) toggleButtonText.textContent = 'Collapse';
        }
    }

    form.addEventListener('click', function(event) {
        const header = event.target.closest('.service-card-header');
        if (header) {
            const card = header.closest('.service-options-card');
            // Toggle the current state and mark it as manually toggled
            setCardCollapseState(card, !card.classList.contains('is-collapsed'));
            card.setAttribute('data-manual-toggle', 'true');
        }
    });

    // --- VALIDATION LOGIC ---
    function validateServiceCard(cardElement) {
        if (!cardElement) return;

        const requiredInputs = cardElement.querySelectorAll('input[required]');
        let isComplete = true;

        for (const input of requiredInputs) {
            if (input.offsetParent !== null && input.value.trim() === '') {
                isComplete = false;
                break;
            }
        }

        if (isComplete) {
            cardElement.classList.add('is-valid');
        } else {
            cardElement.classList.remove('is-valid');
        }

        // Set initial state only if it hasn't been manually toggled by the user
        if (!cardElement.hasAttribute('data-manual-toggle')) {
            setCardCollapseState(cardElement, isComplete); // isComplete being true means it SHOULD be collapsed
        }
    }

    form.addEventListener('input', function(event) {
        const card = event.target.closest('.service-options-card');
        if (card) {
            // Live validation should not affect collapse state, only color
            const requiredInputs = card.querySelectorAll('input[required]');
            let isComplete = true;
            for (const input of requiredInputs) {
                if (input.offsetParent !== null && input.value.trim() === '') {
                    isComplete = false;
                    break;
                }
            }
            if (isComplete) {
                card.classList.add('is-valid');
            } else {
                card.classList.remove('is-valid');
            }
        }
    });

    const deploymentTypeRadios = form.querySelectorAll('input[name="deployment_type"]');
    const serviceCheckboxes = form.querySelectorAll('.service-select-checkbox');
    const noServicesMessage = document.getElementById('no-services-message');
    const addAllButton = document.getElementById('add-all-services');
    const removeAllButton = document.getElementById('remove-all-services');

    function updateRequiredAttributes() {
        const selectedType = form.querySelector('input[name="deployment_type"]:checked').value;
        document.querySelectorAll('.docker-fields input[data-is-required]').forEach(input => {
            input.required = (selectedType === 'docker');
        });
        document.querySelectorAll('.nix-fields input[data-is-required]').forEach(input => {
            input.required = (selectedType === 'nix');
        });
    }

    function toggleDeploymentFields() {
        const selectedType = form.querySelector('input[name="deployment_type"]:checked').value;
        document.querySelectorAll('.deployment-fields').forEach(el => {
            el.style.display = el.classList.contains(selectedType + '-fields') ? 'block' : 'none';
        });
        updateRequiredAttributes();
        document.querySelectorAll('.service-options-card[style*="display: block"]').forEach(validateServiceCard);
    }

    function updateSelectedServicesUI() {
        let hasSelectedServices = false;
        serviceCheckboxes.forEach(checkbox => {
            const cardId = checkbox.dataset.controlsCard;
            const card = document.getElementById(cardId);
            if (!card) return;

            const inputs = card.querySelectorAll('input, select, textarea');

            if (checkbox.checked) {
                hasSelectedServices = true;
                card.style.display = 'block';
                inputs.forEach(input => input.disabled = false);
                validateServiceCard(card); // Validate and set initial collapse state
            } else {
                card.style.display = 'none';
                inputs.forEach(input => input.disabled = true);
                card.removeAttribute('data-manual-toggle'); // Reset manual toggle state when hidden
            }
        });

        if (noServicesMessage) {
            noServicesMessage.style.display = hasSelectedServices ? 'none' : 'block';
        }
        toggleDeploymentFields();
    }

    deploymentTypeRadios.forEach(radio => radio.addEventListener('change', toggleDeploymentFields));
    serviceCheckboxes.forEach(checkbox => checkbox.addEventListener('change', updateSelectedServicesUI));

    if (addAllButton) {
        addAllButton.addEventListener('click', () => {
            serviceCheckboxes.forEach(checkbox => checkbox.checked = true);
            updateSelectedServicesUI();
        });
    }

    if (removeAllButton) {
        removeAllButton.addEventListener('click', () => {
            serviceCheckboxes.forEach(checkbox => checkbox.checked = false);
            updateSelectedServicesUI();
        });
    }

    const serviceSearch = document.getElementById('service-search');
    const serviceList = document.getElementById('service-list').querySelectorAll('li');
    if (serviceSearch) {
        serviceSearch.addEventListener('keyup', () => {
            const filter = serviceSearch.value.toLowerCase();
            serviceList.forEach(item => {
                const label = item.querySelector('label').textContent.toLowerCase();
                item.style.display = label.includes(filter) ? '' : 'none';
            });
        });
    }

    form.querySelectorAll('input[required]').forEach(input => {
        input.setAttribute('data-is-required', 'true');
    });

    updateSelectedServicesUI();
});