const form = document.getElementById('giveawayForm');
const message = document.getElementById('formMessage');

const supabaseReady = Boolean(window.DIV_SUPABASE?.url && window.DIV_SUPABASE?.anonKey && window.supabase);
const client = supabaseReady
  ? window.supabase.createClient(window.DIV_SUPABASE.url, window.DIV_SUPABASE.anonKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    })
  : null;

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
    full_name: data.fullName.trim(),
    email: data.email.trim().toLowerCase(),
    phone: data.phone?.trim() || null,
    country: data.country.trim(),
    app_interest: data.appInterest,
    social_handle: data.socialHandle.trim(),
    proof_url: data.proofUrl?.trim() || null,
    share_repost_confirmed: data.shareRepost === 'on',
    follow_channels_confirmed: data.followChannels === 'on',
    youtube_subscribed_confirmed: data.youtubeSubscribed === 'on',
    consent: data.consent === 'on',
    verification_consent: data.verificationConsent === 'on'
  };

  if (!client) {
    message.className = 'form-message error show';
    message.textContent = 'Giveaway database is not available right now. Please try again later.';
    return;
  }

  try {
    const { error } = await client.from('participants').insert(entry);
    if (error) throw error;

    message.className = 'form-message success show';
    message.textContent = 'Entry submitted successfully. DIV will verify eligible giveaway actions before awarding rewards.';
    form.reset();
  } catch (error) {
    console.error('DIV Giveaway registration error:', error);

    let userMessage = 'We could not submit your entry. Please try again.';
    if (error?.code === '23505') {
      userMessage = 'This email has already been registered for the giveaway.';
    } else if (error?.code === '42501' || /row-level security|permission denied/i.test(error?.message || '')) {
      userMessage = 'DIV registration access was just repaired. Please refresh this page completely (Ctrl+Shift+R) and submit again.';
    } else if (error?.code === 'PGRST204') {
      userMessage = 'The giveaway database is missing a required field. The DIV database schema needs to be updated.';
    } else if (error?.code === 'PGRST205') {
      userMessage = 'The giveaway database table could not be found. Please check the Supabase setup.';
    } else if (error?.message) {
      userMessage = `Registration failed: ${error.message}`;
    }

    message.className = 'form-message error show';
    message.textContent = userMessage;
  }
});
