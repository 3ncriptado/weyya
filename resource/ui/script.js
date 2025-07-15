const tabs = document.querySelectorAll('.tab');
const contents = document.querySelectorAll('.tab-content');

// Detect resource name dynamically to support renamed folders
const resourceName =
  typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'way';

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
  const res = await fetch(`https://${resourceName}/${action}`, {
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

function loadMyOrders() {
  nui('getMyOrders').then((orders) => {
    const container = document.getElementById('myOrders');
    container.innerHTML = '<h2 class="font-bold mb-2">Mis pedidos</h2>';
    (orders || []).forEach((o) => {
      const div = document.createElement('div');
      div.className = 'bg-gray-800 p-2 rounded mt-1 flex justify-between items-center';
      div.innerHTML = `<span>Orden #${o.id} - $${o.total} (${o.estado})</span>`;
      if (o.estado !== 'entregado') {
        const btn = document.createElement('button');
        btn.className = 'pay px-2 py-1 bg-green-600 rounded';
        btn.dataset.id = o.id;
        btn.textContent = 'Pagar';
        div.appendChild(btn);
      }
      container.appendChild(div);
    });
  });
}

let ownerBusiness = null;
let menuItems = [];
let editingId = null;

let pendingPayment = null;



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
  confirm.addEventListener('click', async () => {
    const location = await nui('getPlayerCoords');
    nui('createOrder', { negocio: currentBusiness, items: cart, total, location }).then(() => {
      cart = [];
      updateCart();
    });
  });
  div.appendChild(confirm);
}


// ---------------- BUSINESS MANAGEMENT --------------------
function loadOwnerBusiness() {
  nui('getOwnerBusiness').then((b) => {
    const container = document.getElementById('businessManage');
    container.innerHTML = '';
    ownerBusiness = b;
    if (!b) {
      const div = document.createElement('div');
      div.innerHTML = `
        <h2 class="font-bold mb-2">Registrar Negocio</h2>
        <input id="busName" class="text-black w-full mb-1" placeholder="Nombre" />
        <textarea id="busMenu" class="text-black w-full mb-1" placeholder='Menu JSON'></textarea>
        <button id="registerBusiness" class="px-2 py-1 bg-blue-600 rounded">Registrar</button>`;
      container.appendChild(div);
      return;
    }
    menuItems = b.menu || [];
    const title = document.createElement('h2');
    title.className = 'font-bold mb-2';
    title.textContent = `Gestionar Menú - ${b.nombre}`;
    container.appendChild(title);
    const list = document.createElement('div');
    list.id = 'menuItems';
    container.appendChild(list);
    const form = document.createElement('div');
    form.className = 'mt-2';
    form.innerHTML = `
      <input id="itemLabel" class="text-black w-full mb-1" placeholder="Nombre" />
      <input id="itemPrice" class="text-black w-full mb-1" type="number" placeholder="Precio" />
      <button id="saveItem" class="px-2 py-1 bg-blue-600 rounded">Guardar</button>`;
    container.appendChild(form);
    renderMenuItems();
  });
}

function renderMenuItems() {
  const list = document.getElementById('menuItems');
  if (!list) return;
  list.innerHTML = '';
  menuItems.forEach((item) => {
    const div = document.createElement('div');
    div.className = 'bg-gray-800 p-2 rounded mt-1 flex justify-between items-center';
    div.innerHTML = `<span>${item.label} - $${item.price}</span>
      <div>
        <button class="edit px-2 py-1 bg-yellow-600 rounded mr-1" data-id="${item.id}">Edit</button>
        <button class="delete px-2 py-1 bg-red-600 rounded" data-id="${item.id}">X</button>
      </div>`;
    list.appendChild(div);
  });
}

document.getElementById('businessManage').addEventListener('click', (e) => {
  if (e.target.id === 'registerBusiness') {
    const name = document.getElementById('busName').value;
    let menu;
    try { menu = JSON.parse(document.getElementById('busMenu').value || '[]'); } catch (err) { menu = []; }
    nui('registerBusiness', { name, menu }).then(loadOwnerBusiness);
  }
  if (e.target.id === 'saveItem') {
    const label = document.getElementById('itemLabel').value;
    const price = parseInt(document.getElementById('itemPrice').value);
    if (!label || isNaN(price)) return;
    const data = { id: editingId || Date.now(), label, price };
    nui('updateMenuItem', data).then(() => {
      document.getElementById('itemLabel').value = '';
      document.getElementById('itemPrice').value = '';
      editingId = null;
      loadOwnerBusiness();
    });
  }
  if (e.target.classList.contains('delete')) {
    const id = e.target.dataset.id;
    nui('deleteMenuItem', { id }).then(loadOwnerBusiness);
  }
  if (e.target.classList.contains('edit')) {
    const id = e.target.dataset.id;
    const item = menuItems.find((i) => String(i.id) === String(id));
    if (item) {
      document.getElementById('itemLabel').value = item.label;
      document.getElementById('itemPrice').value = item.price;
      editingId = item.id;
    }
=======
function showPayButton(id) {
  pendingPayment = id;
  const payDiv = document.getElementById('payment');
  payDiv.innerHTML = `<button id="payBtn" data-id="${id}" class="px-2 py-1 bg-green-600 rounded">Pagar</button>`;
  payDiv.classList.remove('hidden');
}

function hidePayButton() {
  pendingPayment = null;
  const payDiv = document.getElementById('payment');
  payDiv.innerHTML = '';
  payDiv.classList.add('hidden');
}

document.getElementById('payment').addEventListener('click', (e) => {
  if (e.target.id === 'payBtn') {
    const id = e.target.dataset.id;
    nui('payOrder', { id }).then(hidePayButton);

  }
});

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
          <button class="reject px-2 py-1 bg-red-600 rounded" data-id="${o.id}">Rechazar</button>
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
  if (e.target.classList.contains('reject')) {
    nui('rejectOrder', { id }).then(loadBusinessOrders);
  }
  if (e.target.classList.contains('ready')) {
    nui('readyOrder', { id }).then(loadBusinessOrders);
  }
});

document.getElementById('myOrders').addEventListener('click', (e) => {
  if (e.target.classList.contains('pay')) {
    const id = e.target.dataset.id;
    nui('payOrder', { id }).then(loadMyOrders);
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
    loadOwnerBusiness();
    loadBusinessOrders();
    loadMyOrders();
    loadDeliveryOrders();
  } else if (e.data === 'close') {
    document.getElementById('app').style.display = 'none';
  } else if (e.data && e.data.action === 'showPay') {
    showPayButton(e.data.id);
  } else if (e.data === 'refreshBusinessOrders') {
    loadBusinessOrders();
  } else if (e.data === 'refreshDeliveryOrders') {
    loadDeliveryOrders();
  }
});

// For local testing without phone
document.addEventListener('DOMContentLoaded', () => {
  loadBusinesses();
  loadOwnerBusiness();
  loadBusinessOrders();
  loadMyOrders();
  loadDeliveryOrders();
});

