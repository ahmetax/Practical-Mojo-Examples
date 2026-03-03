"""
Author: Ahmet Aksoy
Date: 2026-02-23
Revision Date: 2026-02-25
Mojo version no: 0.26.1
"""

fn main() raises:

    fn cmp_fn_desc(a: String, b: String) capturing -> Bool:
        return a > b

    fn cmp_fn_asc(a: String, b: String) capturing -> Bool:
        return a < b

    fn convert_dict_vals_to_list(dict: Dict[String, Int]) -> List[String]:
        var recs: List[String]=[]
        for item in dict.items():
            val = String("00000" + String(item.value))
            if len(val) > 6:
                val = String(val[len(val) - 6:])
            recs.append(String(val) + ": " +item.key)
        return recs^

    var dicts: Dict[String, Int]={"taylor": 3, "bob": 1, "tim": 2, "joe": 13, "rose": 7}
    
    vals = convert_dict_vals_to_list(dicts)
    print(vals)
    
    print("Sorted using values() in descending order")
    sort[cmp_fn_desc](vals)
    for val in vals:
        print(val)    

    
    print("Sorted using values() in ascending order")
    sort[cmp_fn_asc](vals)
    for val in vals:
        print(val)   
