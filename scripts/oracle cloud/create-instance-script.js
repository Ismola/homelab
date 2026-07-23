// ESTE SCRIPT AUTOMATIZA LA CREACION DE UNA INSTANCIA EN ORACLE CLOUD. EJECUTAR DENTRO DE LA CONSOLA DEL NAVEGADOR EN LA PAGINA DE CREACION DE INSTANCIAS: https://cloud.oracle.com/compute/instances/create CON LA CONFIGURACION DE LA INSTANCIA YA SELECCIONADA. EL SCRIPT INTENTA CREAR LA INSTANCIA EN CADA DOMINIO DE DISPONIBILIDAD (AD) HASTA QUE SE CREA CON EXITO. SI NO SE PUEDE CREAR, EL SCRIPT CAMBIA AL SIGUIENTE AD Y VUELVE A INTENTARLO. EL SCRIPT SE DETIENE CUANDO SE CREA LA INSTANCIA O CUANDO SE EJECUTA clearInterval(createInterval) EN LA CONSOLA.

// Search upwards for the AD inputs from the "Availability domain" label
const adLabel = document.querySelectorAll('label').values().find(elem => elem.innerText == 'Availability domain');
if (!adLabel) {
    const msg = 'Failed to find "Availability domain" label on the page. Either your language is not set to English, you aren\'t on https://cloud.oracle.com/compute/instances/create, or this script is outdated.';
    alert(msg);
    throw msg;
}


let ads = [];
let lastParent = adLabel;
while (ads.length == 0) {
    lastParent = lastParent.parentElement;
    if (!lastParent) {
        break;
    }


    ads = [...lastParent.querySelectorAll('input')];
}
if (ads.length == 0) {
    const msg = 'Failed to any labels on the page. This script is likely outdated.';
    alert(msg);
    throw msg;
}


const result = confirm(`Found ${ads.length} availability domains: ${ads.map(elem => elem.value.replace('LCyd:', '')).join(', ')}. Does this look correct?`);
if (!result) {
    throw 'Incorrect available domains detected. This script likely needs to be updated.'
}


let adIndex = 0; // Start with the first AD
function attemptCreate() {
    const adName = ads[adIndex].value.replace('LCyd:', '');
    // Select the next AD
    ads[adIndex].click();
    console.log('Switched to ' + adName);


    // Attempt to find and click the Create button
    let createButton = [...document.querySelectorAll('button[type="button"]')].find(elem => elem.innerText == 'Create');
    if (createButton) {
        createButton.click();
        console.log('Clicked Create on AD ' + adName);
    } else {
        console.log('No Create button found on AD ' + adName);
    }


    // Move to the next AD, loop back to the first AD after the last one
    adIndex = (adIndex + 1) % ads.length;
}


const createInterval = setInterval(attemptCreate, 30000); // Run every 30 seconds
attemptCreate(); // Initial attempt immediately


// To stop the script, run clearInterval(createInterval) in the console.