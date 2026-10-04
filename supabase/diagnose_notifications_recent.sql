select n.id, n.recipient_id, n.business_id, n.title, n.body, n.is_read, n.created_at,
       p.phone as recipient_phone, p.role as recipient_role, p.name as recipient_name
from notifications n
left join profiles p on p.id = n.recipient_id
order by n.created_at desc
limit 20;
