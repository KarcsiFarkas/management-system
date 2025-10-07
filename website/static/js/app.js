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
        lightThemeBtn.addEventListener('click', () => { localStorage.setItem('theme', 'light'); applyTheme('light'); });
        darkThemeBtn.addEventListener('click', () => { localStorage.setItem('theme', 'dark'); applyTheme('dark'); });
    }
    const savedTheme = localStorage.getItem('theme') || 'dark';
    applyTheme(savedTheme);

    // --- 2. DASHBOARD-SPECIFIC LOGIC ---
    const passwordModeSelect = document.getElementById('password_mode_select');
    const customPasswordField = document.getElementById('custom_password_field');

    function toggleCustomPasswordField() {
        if (!passwordModeSelect || !customPasswordField) return;
        customPasswordField.style.display = (passwordModeSelect.value === 'custom') ? 'block' : 'none';
    }

    if (passwordModeSelect) {
        passwordModeSelect.addEventListener('change', toggleCustomPasswordField);
        toggleCustomPasswordField(); // Run on page load
    }

    // --- 3. FORM-SPECIFIC LOGIC ---
    const form = document.getElementById('profile-form');
    if (!form) return;

    // --- DOM ELEMENT SELECTION ---
    const deploymentTypeRadios = form.querySelectorAll('input[name="deployment_type"]');
    const serviceCheckboxes = form.querySelectorAll('.service-select-checkbox');
    const noServicesMessage = document.getElementById('no-services-message');
    const addAllButton = document.getElementById('add-all-services');
    const removeAllButton = document.getElementById('remove-all-services');
    const serviceSearch = document.getElementById('service-search');
    const serviceList = document.getElementById('service-list').querySelectorAll('li');

    // --- HELPER FUNCTIONS ---

    function updateServiceListHighlights() {
        serviceCheckboxes.forEach(checkbox => {
            const listItem = checkbox.closest('li');
            const card = document.getElementById(checkbox.dataset.controlsCard);
            if (!listItem || !card) return;

            if (checkbox.checked) {
                listItem.classList.add('is-selected');
                if (card.classList.contains('is-valid')) {
                    listItem.classList.add('is-valid');
                } else {
                    listItem.classList.remove('is-valid');
                }
            } else {
                listItem.classList.remove('is-selected');
                listItem.classList.remove('is-valid');
            }
        });
    }

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

    function validateServiceCard(cardElement) {
        if (!cardElement) return;
        const requiredInputs = cardElement.querySelectorAll('input[data-is-required="true"]');
        let isComplete = true;

        for (const input of requiredInputs) {
            if (!input.disabled && input.value.trim() === '') {
                isComplete = false;
                break;
            }
        }

        if (isComplete) {
            cardElement.classList.add('is-valid');
        } else {
            cardElement.classList.remove('is-valid');
        }

        if (!cardElement.hasAttribute('data-manual-toggle')) {
            setCardCollapseState(cardElement, isComplete);
        }
        updateServiceListHighlights();
    }

    function toggleDeploymentFields() {
        const selectedType = form.querySelector('input[name="deployment_type"]:checked').value;
        document.querySelectorAll('.deployment-fields').forEach(el => {
            const inputs = el.querySelectorAll('input, select, textarea');
            const isVisibleTab = el.classList.contains(selectedType + '-fields');

            el.style.display = isVisibleTab ? 'block' : 'none';

            inputs.forEach(input => {
                const card = input.closest('.service-options-card');
                const isCardVisible = !card || card.style.display === 'block';

                if (isVisibleTab && isCardVisible) {
                    input.disabled = false;
                    if (input.hasAttribute('data-is-required')) {
                        input.required = true;
                    }
                } else {
                    input.disabled = true;
                    input.required = false;
                }
            });
        });
        document.querySelectorAll('.service-options-card[style*="display: block"]').forEach(validateServiceCard);
    }

    function updateSelectedServicesUI() {
        let hasSelectedServices = false;
        serviceCheckboxes.forEach(checkbox => {
            const cardId = checkbox.dataset.controlsCard;
            const card = document.getElementById(cardId);
            if (!card) return;

            if (checkbox.checked) {
                hasSelectedServices = true;
                card.style.display = 'block';
            } else {
                card.style.display = 'none';
                card.removeAttribute('data-manual-toggle');
            }
        });

        if (noServicesMessage) {
            noServicesMessage.style.display = hasSelectedServices ? 'none' : 'block';
        }
        toggleDeploymentFields();
        updateServiceListHighlights();
    }

    // --- EVENT LISTENERS ---

    form.addEventListener('click', function(event) {
        const header = event.target.closest('.service-card-header');
        if (header && !event.target.closest('a') && !event.target.closest('.remove-service-btn')) {
            const card = header.closest('.service-options-card');
            setCardCollapseState(card, !card.classList.contains('is-collapsed'));
            card.setAttribute('data-manual-toggle', 'true');
        }

        const removeBtn = event.target.closest('.remove-service-btn');
        if (removeBtn) {
            const serviceId = removeBtn.dataset.serviceId;
            const checkbox = document.getElementById(`select_${serviceId}`);
            if (checkbox) {
                checkbox.checked = false;
                checkbox.dispatchEvent(new Event('change'));
            }
        }
    });

    form.addEventListener('input', function(event) {
        const card = event.target.closest('.service-options-card');
        validateServiceCard(card);
    });

    deploymentTypeRadios.forEach(radio => radio.addEventListener('change', toggleDeploymentFields));
    serviceCheckboxes.forEach(checkbox => checkbox.addEventListener('change', updateSelectedServicesUI));

    if (addAllButton) {
        addAllButton.addEventListener('click', () => {
            serviceCheckboxes.forEach(checkbox => {
                checkbox.checked = true;
            });
            updateSelectedServicesUI();
        });
    }

    if (removeAllButton) {
        removeAllButton.addEventListener('click', () => {
            serviceCheckboxes.forEach(checkbox => {
                checkbox.checked = false;
            });
            updateSelectedServicesUI();
        });
    }

    if (serviceSearch) {
        serviceSearch.addEventListener('keyup', () => {
            const filter = serviceSearch.value.toLowerCase();
            serviceList.forEach(item => {
                const label = item.querySelector('label').textContent.toLowerCase();
                item.style.display = label.includes(filter) ? '' : 'none';
            });
        });
    }

    // --- INITIALIZATION ---
    form.querySelectorAll('input[required]').forEach(input => {
        input.setAttribute('data-is-required', 'true');
    });

    updateSelectedServicesUI();
});