import urllib.request, json, base64

print("1. Logueate aquí y COPIA la URL de la página blanca final:\nhttps://ca.account.sony.com/api/authz/v3/oauth/authorize?access_type=offline&client_id=09515159-7237-43f6-bc4a-eb05f3e793cf&redirect_uri=com.scee.psxandroid.sceplogin%3A%2F%2Fredirect&response_type=code&scope=psn%3Asceid%2Cpsn%3Auser_profile%2Cpsn%3Aclient_custom_data%2Cpsn%3Astore_auth%2Cpsn%3Aunified_setup_configs%2Cpsn%3Aaccount_settings%2Cpsn%3Afamily_manager_setup%2Cpsn%3Aservice_entity%2Cpsn%3Aadministration%2Cpsn%3Auser_profile_private%2Cpsn%3Ainternal_network_check%2Cpsn%3Aone_touch_login%2Cpsn%3Aunauthenticated_ps_now_account_linking%2Cpsn%3Aaccount_linking_standard%2Cpsn%3Asession_internal%2Cpsn%3Auser_profile_view%2Cpsn%3Auser_profile_edit%2Cpsn%3Auser_profile_view_private%2Cpsn%3Auser_profile_view_internal%2Cpsn%3Auser_profile_view_private_internal%2Cpsn%3Auser_profile_view_internal_admin%2Cpsn%3Auser_profile_view_private_internal_admin%2Cpsn%3Auser_profile_edit_internal_admin%2Cpsn%3Auser_profile_edit_private_internal_admin%2Cpsn%3Auser_profile_view_internal_admin_all%2Cpsn%3Auser_profile_view_private_internal_admin_all%2Cpsn%3Auser_profile_edit_internal_admin_all%2Cpsn%3Auser_profile_edit_private_internal_admin_all\n")

url = input("2. Pega la URL de la página blanca aquí: ").strip()

try:
    auth_code = url.split('code=')[1].split('&')[0]
    
    # Intercambio de código por Token
    data = f"grant_type=authorization_code&code={auth_code}&redirect_uri=com.scee.psxandroid.sceplogin://redirect".encode()
    headers = {"Authorization": "Basic MDk1MTUxNTktNzIzNy00M2Y2LWJjNGEtZWIwNWYzZTc5M2NmOmF3NVp3Y056aHR0S3VjM0g="}
    req = urllib.request.Request("https://ca.account.sony.com/api/authz/v3/oauth/token", data=data, headers=headers)
    
    with urllib.request.urlopen(req) as f:
        token = json.loads(f.read().decode())['access_token']
        
    # Obtención del Account ID
    req_id = urllib.request.Request("https://ssw.live.playstation.com/api/v1/users/me/profile/accountNumber", headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req_id) as f:
        account_id_raw = json.loads(f.read().decode())['accountNumber']
        
    # Conversión a Base64 para Chiaki
    account_id_b64 = base64.b64encode(account_id_raw.encode()).decode()
    print(f"\n✅ TU ID PARA CHIAKI ES: {account_id_b64}")

except Exception as e:
    print(f"\n❌ Error: Asegúrate de pegar la URL correcta que contiene 'code='.")
