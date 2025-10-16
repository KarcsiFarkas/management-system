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

    // --- 2. UNIVERSAL COLLAPSE LOGIC FOR CARDS ---
    document.body.addEventListener('click', function(event) {
        const header = event.target.closest('.service-card-header');
        if (header && !event.target.closest('a') && !event.target.closest('.remove-service-btn')) {
            const card = header.closest('.service-options-card, .summary-card');
            const toggleText = card.querySelector('.toggle-text');
            card.classList.toggle('is-collapsed');
            if (toggleText) {
                toggleText.textContent = card.classList.contains('is-collapsed') ? 'Expand' : 'Collapse';
            }
        }
    });


    // --- 3. FORM-SPECIFIC LOGIC ---
    const form = document.getElementById('profile-form');
    if (!form) return; // Exit if not on the form page

    // --- DOM ELEMENT SELECTION ---
    const deploymentTypeRadios = form.querySelectorAll('input[name="deployment_runtime"]');
    const serviceCheckboxes = form.querySelectorAll('.service-select-checkbox');
    const noServicesMessage = document.getElementById('no-services-message');
    const addAllButton = document.getElementById('add-all-services');
    const removeAllButton = document.getElementById('remove-all-services');
    const serviceSearch = document.getElementById('service-search');
    const serviceList = document.getElementById('service-list').querySelectorAll('li');
    const passwordModeSelect = document.getElementById('password_mode_select');
    const customPasswordField = document.getElementById('custom_password_field');

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

    function validateServiceCard(cardElement) {
        if (!cardElement) return;
        const requiredInputs = cardElement.querySelectorAll('input[required]');
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
        updateServiceListHighlights();
    }

    function toggleDeploymentFields() {
        const selectedType = form.querySelector('input[name="deployment_runtime"]:checked').value;
        document.querySelectorAll('.deployment-fields').forEach(el => {
            const isVisibleTab = el.classList.contains(selectedType + '-fields');
            el.style.display = isVisibleTab ? 'block' : 'none';

            // Only enable/disable fields if the parent service card is visible (selected)
            const parentCard = el.closest('.service-options-card');
            const isServiceSelected = parentCard && parentCard.style.display === 'block';

            el.querySelectorAll('input, select, textarea').forEach(input => {
                if (isServiceSelected) {
                    // Only enable/disable based on deployment type if service is selected
                    input.disabled = !isVisibleTab;
                } else {
                    // Keep fields disabled if service is not selected
                    input.disabled = true;
                }
            });
        });
        document.querySelectorAll('.service-options-card').forEach(card => {
            if (card.style.display === 'block') {
                validateServiceCard(card);
            }
        });
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
                // Enable required fields when card is shown
                card.querySelectorAll('input[required]').forEach(input => {
                    input.disabled = false;
                });
                validateServiceCard(card);
            } else {
                card.style.display = 'none';
                // Disable required fields when card is hidden to prevent form validation issues
                card.querySelectorAll('input[required]').forEach(input => {
                    input.disabled = true;
                });
            }
        });

        if (noServicesMessage) {
            noServicesMessage.style.display = hasSelectedServices ? 'none' : 'block';
        }
        toggleDeploymentFields();
    }

    function toggleCustomPasswordField() {
        if (!passwordModeSelect || !customPasswordField) return;
        customPasswordField.style.display = (passwordModeSelect.value === 'custom') ? 'block' : 'none';
    }


    // --- EVENT LISTENERS ---

    form.addEventListener('click', function(event) {
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
        if (event.target.closest('.service-options-card')) {
            validateServiceCard(event.target.closest('.service-options-card'));
        }
    });

    deploymentTypeRadios.forEach(radio => radio.addEventListener('change', toggleDeploymentFields));
    serviceCheckboxes.forEach(checkbox => checkbox.addEventListener('change', updateSelectedServicesUI));

    if (addAllButton) {
        addAllButton.addEventListener('click', () => {
            serviceCheckboxes.forEach(checkbox => {
                if (checkbox.closest('li').style.display !== 'none') {
                    checkbox.checked = true;
                }
            });
            updateSelectedServicesUI();
        });
    }

    if (removeAllButton) {
        removeAllButton.addEventListener('click', () => {
            serviceCheckboxes.forEach(checkbox => {
                if (checkbox.closest('li').style.display !== 'none') {
                    checkbox.checked = false;
                }
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

    if (passwordModeSelect) {
        passwordModeSelect.addEventListener('change', toggleCustomPasswordField);
    }

    // --- GLOBAL TOGGLE FUNCTIONALITY ---
    // Add event listeners for all toggle buttons (works on dashboard and form pages)
    document.addEventListener('click', function(event) {
        const toggleButton = event.target.closest('.toggle-button');
        if (toggleButton) {
            const card = toggleButton.closest('.card');
            if (card) {
                const isCollapsed = card.classList.contains('is-collapsed');
                const toggleText = toggleButton.querySelector('.toggle-text');

                if (isCollapsed) {
                    card.classList.remove('is-collapsed');
                    if (toggleText) toggleText.textContent = 'Collapse';
                } else {
                    card.classList.add('is-collapsed');
                    if (toggleText) toggleText.textContent = 'Expand';
                }
            }
        }
    });

    // --- INITIALIZATION ---
    updateSelectedServicesUI();
});
