const form = document.getElementById('giveawayForm');
const message = document.getElementById('formMessage');

// Connect this handler to Supabase/Firebase after the project credentials are configured.
// Do not put a service-role key, admin password, or private API key in this file.
form.addEventListener('submit', async (event) => {
  event.preventDefault();
  message.className = 'form-message';
  message.textContent = '';

  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }

  const data = Object.fromEntries(new FormData(form).entries());
  const entry = {
    fullName: data.fullName.trim(),
    email: data.email.trim().toLowerCase(),
    phone: data.phone?.trim() || null,
    country: data.country.trim(),
    appInterest: data.appInterest,
    socialHandle: data.socialHandle?.trim() || null,
    consent: data.consent === 'on'
  };

  // TODO: POST entry to your secure backend.
  // Example architecture: Supabase table `participants` with RLS allowing INSERT only.
  // Never read the participant table from this public page.
  console.log('Giveaway entry ready for secure backend:', { ...entry, email: '[protected until backend is connected]' });

  message.className = 'form-message success show';
  message.textContent = 'Your entry is ready. The secure database connection still needs to be configured by the admin.';
  form.reset();
});