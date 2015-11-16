/* Copyright 2015 Samsung Electronics Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "jerry.h"
#include "jerry-api.h"
#include "plugins/lib-device-stm/actuators.h"
#include "plugins/lib-device-stm/common-io.h"

/**
 * Standalone Jerry exit codes
 */
#define JERRY_STANDALONE_EXIT_CODE_OK   (0)
#define JERRY_STANDALONE_EXIT_CODE_FAIL (1)


#include JERRY_MCU_SCRIPT_HEADER
static const char generated_source [] = JERRY_MCU_SCRIPT;
size_t strlen(const char* str);

static bool ledon_js(const jerry_api_object_t *function_obj_p,
                   const jerry_api_value_t *this_p,
                   jerry_api_value_t *ret_val_p,
                   const jerry_api_value_t args_p [],
                   const uint16_t args_count)
{

  if (function_obj_p == NULL || this_p ==NULL || args_p == NULL ||
      args_count == 0) {}

  jerry_api_value_t val = args_p[0];
  if (val.type == JERRY_API_DATA_TYPE_UINT32) {
    uint32_t led_num = val.v_uint32;
    led_on(led_num);
  }
  else if (val.type == JERRY_API_DATA_TYPE_FLOAT64) {
    led_on((uint32_t)val.v_float64);
  }
   else if (val.type == JERRY_API_DATA_TYPE_FLOAT32) {
    led_on((uint32_t)val.v_float32);
  }
  else {
    fake_exit();
  }





  ret_val_p->type = JERRY_API_DATA_TYPE_BOOLEAN;
  ret_val_p->v_bool = true;

  return true;
}

static bool ledoff_js(const jerry_api_object_t *function_obj_p,
                   const jerry_api_value_t *this_p,
                   jerry_api_value_t *ret_val_p,
                   const jerry_api_value_t args_p [],
                   const uint16_t args_count)
{

  if (function_obj_p == NULL || this_p ==NULL || args_p == NULL ||
      args_count == 0) {}

  jerry_api_value_t val = args_p[0];
  if (val.type == JERRY_API_DATA_TYPE_UINT32) {
    uint32_t led_num = val.v_uint32;
    led_off(led_num);
  }
  else if (val.type == JERRY_API_DATA_TYPE_FLOAT64) {
    led_off((uint32_t)val.v_float64);
  }
  else if (val.type == JERRY_API_DATA_TYPE_FLOAT32) {
    led_off((uint32_t)val.v_float32);
  }
  else {
    fake_exit();
  }

  ret_val_p->type = JERRY_API_DATA_TYPE_BOOLEAN;
  ret_val_p->v_bool = true;

  return true;
  }

size_t strlen(const char* str)
{
  size_t i=0;
  while(str[i] != '\0') {
    i++;
  }
  return i;
}

int
main (void)
{
  initialize_leds();


  jerry_init(JERRY_FLAG_EMPTY);
  jerry_api_object_t * obj_p1 = jerry_api_create_external_function (ledon_js);
  jerry_api_object_t * obj_p2 = jerry_api_create_external_function (ledoff_js);
  jerry_api_object_t * glob_obj_p = jerry_api_get_global ();

  jerry_api_value_t val1;
  val1.type = JERRY_API_DATA_TYPE_OBJECT;
  val1.v_object = obj_p1;

  jerry_api_value_t val2;
  val2.type = JERRY_API_DATA_TYPE_OBJECT;
  val2.v_object = obj_p2;

  jerry_api_set_object_field_value (glob_obj_p, "led_on", &val1);
  jerry_api_set_object_field_value (glob_obj_p, "led_off", &val2);


  // js-execution
  const char *source_p = generated_source;
  const size_t source_size = strlen (generated_source);



  jerry_parse (source_p, source_size);

  jerry_run ();


  jerry_cleanup();

  return 0;

}
