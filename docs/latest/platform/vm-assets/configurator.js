
(() => {
  const $ = id => document.getElementById(id);
  const providers = {
    openai: { prefix: 'openai/', label: 'OpenAI API key', key: 'OPENAI_API_KEY', url: 'https://platform.openai.com/docs/quickstart' },
    anthropic: { prefix: 'anthropic/', label: 'Anthropic API key', key: 'ANTHROPIC_API_KEY', url: 'https://docs.anthropic.com/en/api/getting-started' },
    bedrock: { prefix: 'bedrock/', label: 'Bedrock bearer token', key: 'AWS_BEARER_TOKEN_BEDROCK', url: 'https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started.html' }
  };
  const authProviders = [
    ['github', 'GitHub', 'AUTH_GITHUB'], ['gitlab', 'GitLab', 'AUTH_GITLAB'], ['bitbucket', 'Bitbucket Cloud', 'AUTH_BITBUCKET']
  ];
  const escapeYamlBlock = value => String(value).replace(/\r/g, '').split('\n').map(line => '      ' + line).join('\n');
  const file = (path, content) => `  - path: ${path}\n    owner: root:root\n    permissions: '0600'\n    content: |\n${escapeYamlBlock(content)}\n`;
  const envValue = (key, value) => `${key}=${value}`;

  function syncProvider() {
    const p = providers[$('llm-provider').value];
    $('llm-docs').innerHTML = `<a href="${p.url}">Provider setup documentation</a>`;
    $('llm-key-label').firstChild.textContent = p.label + ' ';
    $('llm-region-label').hidden = $('llm-provider').value !== 'bedrock';
    $('llm-key').setAttribute('aria-label', p.label);
    const input = $('llm-model');
    if (!input.value || Object.values(providers).some(x => input.value.startsWith(x.prefix))) input.value = p.prefix;
  }
  function syncAuthFields() {
    const previous = {};
    authProviders.forEach(([id]) => {
      for (const suffix of ['id', 'secret']) {
        const input = $(`${id}-${suffix}`);
        if (input) previous[input.id] = input.value;
      }
    });
    $('auth-fields').innerHTML = authProviders.filter(([id]) => $(`${id}-enabled`).checked).map(([id, name, prefix]) =>
      `<fieldset><legend>${name} OAuth app</legend><div class="field-grid"><label>Client ID <input id="${id}-id" autocomplete="off"></label><label>Client secret <input id="${id}-secret" type="password" autocomplete="new-password"></label></div></fieldset>`).join('');
    Object.entries(previous).forEach(([id, value]) => { if ($(id)) $(id).value = value; });
    render();
  }
  function render() {
    const errors = [];
    const p = providers[$('llm-provider').value];
    const unsafeCharacters = Array.from(document.querySelectorAll('.vm-configurator input')).some(input => /[\r\n\0]/.test(input.value));
    if (unsafeCharacters) errors.push('Values must be single-line and contain no null characters before export.');
    if (!$('llm-model').value.trim().startsWith(p.prefix) || $('llm-model').value.trim() === p.prefix) errors.push('Enter a model ID with the selected provider prefix.');
    if (!$('llm-key').value.trim()) errors.push('Enter an API key or dummy development token.');
    if ($('llm-provider').value === 'bedrock' && !$('llm-region').value.trim()) errors.push('Enter an AWS region.');
    if ($('llm-max').value.trim() && !/^[1-9][0-9]*$/.test($('llm-max').value.trim())) errors.push('Max tokens must be a positive integer.');
    if ($('aap-url').value.trim() || $('aap-token').value) {
      if (!/^https:\/\/[^\s]+$/.test($('aap-url').value.trim()) || !$('aap-token').value.trim()) errors.push('AAP requires an HTTPS controller URL and token.');
    }
    authProviders.forEach(([id, name]) => {
      if ($(`${id}-enabled`).checked && (!$(`${id}-id`).value.trim() || !$(`${id}-secret`).value.trim())) errors.push(`${name} requires both a client ID and secret.`);
    });
    $('vm-config-status').textContent = errors.length
      ? 'Draft configuration — ' + errors.join(' ') + ' Preview updates as you type; incomplete settings may not work in the VM.'
      : 'Ready. The generated file contains credentials; handle it as a secret.';
    // Validation is advisory: allow placeholders and partially completed settings.
    // Only unsafe env-file characters prevent export, never rendering.
    $('copy').disabled = $('download').disabled = unsafeCharacters;
    const llm = [envValue('LLM_MODEL', $('llm-model').value.trim() || p.prefix), envValue(p.key, $('llm-key').value)];
    if ($('llm-provider').value === 'bedrock') llm.push(envValue('AWS_REGION', $('llm-region').value.trim()));
    if ($('llm-max').value.trim()) llm.push(envValue('MAX_TOKENS', $('llm-max').value.trim()));
    const files = [file('/etc/x2a/llm.env', llm.join('\n'))];
    const aap = [];
    if ($('aap-url').value.trim()) aap.push(envValue('AAP_CONTROLLER_URL', $('aap-url').value.trim()));
    if ($('aap-org').value.trim()) aap.push(envValue('AAP_ORG_NAME', $('aap-org').value.trim()));
    if ($('aap-token').value) aap.push(envValue('AAP_OAUTH_TOKEN', $('aap-token').value));
    if (!$('aap-verify').checked) aap.push('AAP_VERIFY_SSL=false');
    const aapConfigured = $('aap-url').value.trim() || $('aap-token').value ||
      $('aap-org').value.trim() !== 'Default' || !$('aap-verify').checked;
    files.push(file('/etc/x2a/aap.env', aapConfigured ? aap.join('\n') : ''));
    const auth = [];
    authProviders.forEach(([id, , prefix]) => {
      if ($(`${id}-enabled`).checked) {
        auth.push(envValue(`${prefix}_CLIENT_ID`, $(`${id}-id`).value || ''));
        auth.push(envValue(`${prefix}_CLIENT_SECRET`, $(`${id}-secret`).value || ''));
      }
    });
    files.push(file('/etc/x2a/auth.env', auth.join('\n')));
    $('output').value = '#cloud-config\n# Generated locally. Do not use real credentials with a plain-HTTP seed.\nwrite_files:\n' + files.join('\n');
  }

  $('llm-provider').addEventListener('change', () => { syncProvider(); render(); });
  authProviders.forEach(([id]) => $(`${id}-enabled`).addEventListener('change', syncAuthFields));
  document.querySelector('.vm-configurator').addEventListener('input', render);
  document.querySelector('.vm-configurator').addEventListener('change', render);
  $('copy').addEventListener('click', async () => {
    try { await navigator.clipboard.writeText($('output').value); $('copy').textContent = 'Copied'; }
    catch {
      $('output').focus(); $('output').select();
      $('vm-config-status').textContent = 'Clipboard unavailable. Copy the selected output manually.';
    }
    setTimeout(() => $('copy').textContent = 'Copy YAML', 1500);
  });
  $('download').addEventListener('click', () => {
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([$('output').value], {type: 'text/plain'})); a.download = 'user-data'; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  });
  syncProvider(); syncAuthFields(); render();
})();
