const tabs = document.querySelectorAll('.tab');
const contents = document.querySelectorAll('.tab-content');

tabs.forEach((btn) => {
  btn.addEventListener('click', () => {
    tabs.forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    const name = btn.dataset.tab;
    contents.forEach((c) => c.classList.add('hidden'));
    document.getElementById(name).classList.remove('hidden');
  });
});

// Utility to send data to FiveM
async function nui(action, data) {
  const res = await fetch(`https://way/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
  });
  try {
    return await res.json();
  } catch (e) {
    return null;
  }
}

// CLIENT VIEW --------------------------------------------------------------
let currentBusiness = null;
let cart = [];

function loadBusinesses() {
  nui('getBusinesses').then((list) => {
    if (!Array.isArray(list)) return;
    const container = document.getElementById('businessList');
    container.innerHTML = '';
    list.forEach((b) => {
      const div = document.createElement('div');
      div.className = 'bg-gray-800 p-2 rounded flex justify-between items-center';
      div.innerHTML = `<span>${b.nombre}</span><button class="px-2 py-1 bg-blue-600 rounded" data-id="${b.id}">Ver menú</button>`;
      container.appendChild(div);
    });
  });
}

document.getElementById('businessList').addEventListener('click', (e) => {
  if (e.target.tagName === 'BUTTON') {
    const id = e.target.dataset.id;
    nui('getBusinessMenu', { id }).then((menu) => {
      currentBusiness = id;
      showMenu(menu || []);
    });
  }
});

function showMenu(menu) {
  const menuDiv = document.getElementById('menu');
  menuDiv.innerHTML = '';
  menuDiv.classList.remove('hidden');
  cart = [];
  updateCart();
  menu.forEach((item) => {
    const div = document.createElement('div');
    div.className = 'bg-gray-700 p-2 rounded flex justify-between items-center mt-1';
    div.innerHTML = `<span>${item.label} - $${item.price}</span><button class="add px-2 py-1 bg-green-600 rounded" data-id="${item.id}">Agregar</button>`;
    menuDiv.appendChild(div);
  });
}

document.getElementById('menu').addEventListener('click', (e) => {
  if (e.target.classList.contains('add')) {
    const id = e.target.dataset.id;
    const name = e.target.parentElement.querySelector('span').textContent;
    const price = parseInt(name.split('$')[1]);
    cart.push({ id, label: name.split(' - ')[0], price });
    updateCart();
  }
});

function updateCart() {
  const div = document.getElementById('cart');
  if (cart.length === 0) {
    div.classList.add('hidden');
    div.innerHTML = '';
    return;
  }
  div.classList.remove('hidden');
  let total = cart.reduce((a, b) => a + b.price, 0);
  div.innerHTML = `<h2 class="font-bold mb-2">Carrito</h2>`;
  cart.forEach((i) => {
    const p = document.createElement('p');
    p.textContent = `${i.label} - $${i.price}`;
    div.appendChild(p);
  });
  const confirm = document.createElement('button');
  confirm.textContent = `Confirmar pedido ($${total})`;
  confirm.className = 'mt-2 px-2 py-1 bg-blue-600 rounded';
  confirm.addEventListener('click', () => {
    nui('createOrder', { negocio: currentBusiness, items: cart, total }).then(() => {
      cart = [];
      updateCart();
    });
  });
  div.appendChild(confirm);
}

// BUSINESS VIEW ------------------------------------------------------------
function loadBusinessOrders() {
  nui('getBusinessOrders').then((orders) => {
    const container = document.getElementById('businessOrders');
    container.innerHTML = '';
    (orders || []).forEach((o) => {
      const div = document.createElement('div');
      div.className = 'bg-gray-800 p-2 rounded mt-1';
      div.innerHTML = `
        <p>Orden #${o.id} - $${o.total}</p>
        <div class="mt-2 flex space-x-2">
          <button class="accept px-2 py-1 bg-green-600 rounded" data-id="${o.id}">Aceptar</button>
          <button class="ready px-2 py-1 bg-yellow-600 rounded" data-id="${o.id}">Enviar a delivery</button>
        </div>`;
      container.appendChild(div);
    });
  });
}

document.getElementById('businessOrders').addEventListener('click', (e) => {
  const id = e.target.dataset.id;
  if (e.target.classList.contains('accept')) {
    nui('acceptOrder', { id }).then(loadBusinessOrders);
  }
  if (e.target.classList.contains('ready')) {
    nui('readyOrder', { id }).then(loadBusinessOrders);
  }
});

// DELIVERY VIEW ------------------------------------------------------------
function loadDeliveryOrders() {
  nui('getAvailableOrders').then((orders) => {
    const container = document.getElementById('deliveryOrders');
    container.innerHTML = '';
    (orders || []).forEach((o) => {
      const div = document.createElement('div');
      div.className = 'bg-gray-800 p-2 rounded mt-1 flex justify-between items-center';
      div.innerHTML = `Orden #${o.id} - $${o.total} <button class="take px-2 py-1 bg-blue-600 rounded" data-id="${o.id}">Tomar</button>`;
      container.appendChild(div);
    });
  });
}

document.getElementById('deliveryOrders').addEventListener('click', (e) => {
  if (e.target.classList.contains('take')) {
    const id = e.target.dataset.id;
    nui('takeOrder', { id }).then(loadDeliveryOrders);
  }
});

// INIT --------------------------------------------------------------------
window.addEventListener('message', (e) => {
  if (e.data === 'open') {
    document.getElementById('app').style.display = 'block';
    loadBusinesses();
    loadBusinessOrders();
    loadDeliveryOrders();
  } else if (e.data === 'close') {
    document.getElementById('app').style.display = 'none';
  } else if (e.data === 'refreshBusinessOrders') {
    loadBusinessOrders();
  } else if (e.data === 'refreshDeliveryOrders') {
    loadDeliveryOrders();
  }
});

// For local testing without phone
document.addEventListener('DOMContentLoaded', () => {
  loadBusinesses();
  loadBusinessOrders();
  loadDeliveryOrders();
});

