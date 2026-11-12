(() => {
  document.querySelectorAll('ul.tab').forEach(tabList => {
    const panelList = document.getElementById(tabList.dataset.tab);
    if (!panelList) return;

    const tabs = Array.from(tabList.querySelectorAll(':scope > li > a'));
    const panels = Array.from(panelList.querySelectorAll(':scope > li'));
    if (!tabs.length || tabs.length !== panels.length) return;

    panelList.classList.add('tabs-enhanced');
    tabList.setAttribute('role', 'tablist');
    tabList.setAttribute('aria-orientation', 'horizontal');

    function select(index, moveFocus = false) {
      tabs.forEach((tab, tabIndex) => {
        const selected = tabIndex === index;
        const tabItem = tab.parentElement;
        tabItem.classList.toggle('active', selected);
        tab.setAttribute('role', 'tab');
        tab.id = `${tabList.id}-tab-${tabIndex}`;
        panels[tabIndex].id = `${panelList.id}-panel-${tabIndex}`;
        tab.setAttribute('aria-controls', panels[tabIndex].id);
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        tab.href = `#${panels[tabIndex].id}`;

        panels[tabIndex].setAttribute('role', 'tabpanel');
        panels[tabIndex].setAttribute('aria-labelledby', tab.id);
        panels[tabIndex].hidden = !selected;
        panels[tabIndex].classList.toggle('active', selected);
      });
      if (moveFocus) tabs[index].focus();
    }

    const initialIndex = Math.max(0, tabs.findIndex(tab => tab.parentElement.classList.contains('active')));
    select(initialIndex);

    tabs.forEach((tab, index) => {
      tab.addEventListener('click', event => {
        event.preventDefault();
        select(index);
      });
      tab.addEventListener('keydown', event => {
        let nextIndex;
        if (event.key === 'ArrowRight') nextIndex = (index + 1) % tabs.length;
        else if (event.key === 'ArrowLeft') nextIndex = (index - 1 + tabs.length) % tabs.length;
        else if (event.key === 'Home') nextIndex = 0;
        else if (event.key === 'End') nextIndex = tabs.length - 1;
        else return;
        event.preventDefault();
        select(nextIndex, true);
      });
    });
  });
})();
